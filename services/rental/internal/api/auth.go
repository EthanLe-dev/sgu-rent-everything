package api

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"net/mail"
	"net/smtp"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

func (s *Server) handleSendOTP(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email string `json:"email"`
	}
	if _, ok := readBodyAndDecode(w, r, &req); !ok {
		return
	}
	email := strings.ToLower(strings.TrimSpace(req.Email))
	addr, err := mail.ParseAddress(email)
	if err != nil || addr.Address != email {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Email không hợp lệ.", map[string]string{"email": "Email không hợp lệ"})
		return
	}

	now := s.now().UTC()
	cooldown := s.cfg.OTPCooldownSeconds
	if cooldown > 0 {
		var lastCreated time.Time
		err := s.db.QueryRow(r.Context(), `
			SELECT created_at FROM otp_challenges
			WHERE email = $1 AND created_at > $2
			ORDER BY created_at DESC LIMIT 1
		`, email, now.Add(-time.Duration(cooldown)*time.Second)).Scan(&lastCreated)
		if err == nil {
			retryAfter := int(time.Until(lastCreated.Add(time.Duration(cooldown)*time.Second)).Seconds()) + 1
			if retryAfter < 1 {
				retryAfter = 1
			}
			w.Header().Set("Retry-After", strconv.Itoa(retryAfter))
			writeError(w, http.StatusTooManyRequests, "rate_limited", "Vui lòng chờ trước khi yêu cầu mã OTP mới.", nil)
			return
		}
	}

	var recentCount int
	_ = s.db.QueryRow(r.Context(), `
		SELECT COUNT(*) FROM otp_challenges
		WHERE email = $1 AND created_at > $2
	`, email, now.Add(-15*time.Minute)).Scan(&recentCount)
	if recentCount >= 5 {
		w.Header().Set("Retry-After", "60")
		writeError(w, http.StatusTooManyRequests, "rate_limited", "Bạn đã yêu cầu OTP quá nhiều lần. Thử lại sau.", nil)
		return
	}

	var globalBurst int
	_ = s.db.QueryRow(r.Context(), `
		SELECT COUNT(*) FROM otp_challenges
		WHERE created_at > $1
	`, now.Add(-1*time.Minute)).Scan(&globalBurst)
	if globalBurst >= 30 {
		w.Header().Set("Retry-After", "30")
		writeError(w, http.StatusTooManyRequests, "rate_limited", "Hệ thống đang bận gửi mã OTP, vui lòng thử lại sau ít giây.", nil)
		return
	}

	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tạo mã OTP.", nil)
		return
	}
	code := fmt.Sprintf("%06d", n.Int64())
	challengeID := newID("otp")
	expiresAt := now.Add(10 * time.Minute)
	codeHash := sha256Hex(challengeID + ":" + code + ":" + s.cfg.OTPPepper)

	if _, err := s.db.Exec(r.Context(), `
		INSERT INTO otp_challenges (id, email, code_hash, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`, challengeID, email, codeHash, expiresAt, now); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể lưu yêu cầu OTP.", nil)
		return
	}

	if err := s.sendOTPEmail(email, code); err != nil {
		writeError(w, http.StatusServiceUnavailable, "service_unavailable", "Không thể gửi email OTP lúc này.", nil)
		return
	}

	writeJSON(w, http.StatusAccepted, map[string]string{
		"challenge_id": challengeID,
		"expires_at":   formatTS(expiresAt),
	})
}

func (s *Server) sendOTPEmail(to, code string) error {
	if s.cfg.SMTPHost == "" {
		return nil
	}
	from := s.cfg.SMTPFrom
	if from == "" {
		from = "no-reply@sgu.test"
	}
	msg := fmt.Sprintf(
		"From: %s\r\nTo: %s\r\nSubject: Ma OTP dang nhap Thue Do Sinh Vien\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\nMa OTP cua ban la: %s\r\nMa co hieu luc trong 10 phut.\r\n",
		from, to, code,
	)
	addr := s.cfg.SMTPHost + ":" + s.cfg.SMTPPort
	return smtp.SendMail(addr, nil, from, []string{to}, []byte(msg))
}

func (s *Server) handleVerifyOTP(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ChallengeID string `json:"challenge_id"`
		Code        string `json:"code"`
	}
	if _, ok := readBodyAndDecode(w, r, &req); !ok {
		return
	}
	if strings.TrimSpace(req.ChallengeID) == "" || strings.TrimSpace(req.Code) == "" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Thiếu mã thử thách hoặc mã OTP.", nil)
		return
	}

	now := s.now().UTC()
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
		return
	}
	defer tx.Rollback(r.Context())

	var email, codeHash string
	var attempts int
	var expiresAt time.Time
	var consumedAt *time.Time
	err = tx.QueryRow(r.Context(), `
		SELECT email, code_hash, attempts, expires_at, consumed_at
		FROM otp_challenges WHERE id = $1 FOR UPDATE
	`, req.ChallengeID).Scan(&email, &codeHash, &attempts, &expiresAt, &consumedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusUnauthorized, "invalid_otp", "Mã OTP không đúng hoặc đã hết hạn.", nil)
		return
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
		return
	}

	if attempts >= 5 {
		w.Header().Set("Retry-After", "60")
		writeError(w, http.StatusTooManyRequests, "rate_limited", "Bạn đã nhập sai OTP quá nhiều lần.", nil)
		return
	}
	if consumedAt != nil || now.After(expiresAt) {
		writeError(w, http.StatusUnauthorized, "invalid_otp", "Mã OTP không đúng hoặc đã hết hạn.", nil)
		return
	}

	expectedHash := sha256Hex(req.ChallengeID + ":" + strings.TrimSpace(req.Code) + ":" + s.cfg.OTPPepper)
	if subtle.ConstantTimeCompare([]byte(codeHash), []byte(expectedHash)) != 1 {
		_, _ = tx.Exec(r.Context(), `UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = $1`, req.ChallengeID)
		_ = tx.Commit(r.Context())
		writeError(w, http.StatusUnauthorized, "invalid_otp", "Mã OTP không đúng hoặc đã hết hạn.", nil)
		return
	}

	if _, err := tx.Exec(r.Context(), `UPDATE otp_challenges SET consumed_at = $2 WHERE id = $1`, req.ChallengeID, now); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi xác thực OTP.", nil)
		return
	}

	var me Me
	err = tx.QueryRow(r.Context(), `
		SELECT id, display_name, (verification = 'approved'), email, role, verification,
		       full_name, student_code, class_name, faculty, review_note
		FROM users WHERE email = $1
	`, email).Scan(
		&me.ID, &me.DisplayName, &me.Verified, &me.Email, &me.Role, &me.Verification,
		&me.FullName, &me.StudentCode, &me.ClassName, &me.Faculty, &me.ReviewNote,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		userID := newID("user")
		displayName := strings.Split(email, "@")[0]
		err = tx.QueryRow(r.Context(), `
			INSERT INTO users (id, email, display_name, role, verification)
			VALUES ($1, $2, $3, 'student', 'unsubmitted')
			RETURNING id, display_name, (verification = 'approved'), email, role, verification,
			          full_name, student_code, class_name, faculty, review_note
		`, userID, email, displayName).Scan(
			&me.ID, &me.DisplayName, &me.Verified, &me.Email, &me.Role, &me.Verification,
			&me.FullName, &me.StudentCode, &me.ClassName, &me.Faculty, &me.ReviewNote,
		)
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tải hồ sơ người dùng.", nil)
		return
	}

	token := randomToken()
	sessionID := newID("sess")
	sessionExp := now.Add(7 * 24 * time.Hour)
	if _, err := tx.Exec(r.Context(), `
		INSERT INTO sessions (id, user_id, token_hash, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`, sessionID, me.ID, sha256Hex(token), sessionExp, now); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tạo phiên đăng nhập.", nil)
		return
	}

	if err := tx.Commit(r.Context()); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hoàn tất đăng nhập.", nil)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"access_token": token,
		"expires_at":   formatTS(sessionExp),
		"me":           me,
	})
}

func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request, me Me) {
	_, sessionID, err := s.authenticate(r)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "unauthenticated", "Vui lòng đăng nhập lại.", nil)
		return
	}
	_, _ = s.db.Exec(r.Context(), `UPDATE sessions SET revoked_at = $2 WHERE id = $1`, sessionID, s.now().UTC())
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleGetMe(w http.ResponseWriter, r *http.Request, me Me) {
	writeJSON(w, http.StatusOK, me)
}

func (s *Server) handlePutVerification(w http.ResponseWriter, r *http.Request, me Me) {
	var req struct {
		FullName    string `json:"full_name"`
		StudentCode string `json:"student_code"`
		ClassName   string `json:"class_name"`
		Faculty     string `json:"faculty"`
		DisplayName string `json:"display_name"`
	}
	if _, ok := readBodyAndDecode(w, r, &req); !ok {
		return
	}
	fields := map[string]string{}
	if strings.TrimSpace(req.FullName) == "" {
		fields["full_name"] = "Bắt buộc"
	}
	if strings.TrimSpace(req.StudentCode) == "" {
		fields["student_code"] = "Bắt buộc"
	}
	if strings.TrimSpace(req.ClassName) == "" {
		fields["class_name"] = "Bắt buộc"
	}
	if strings.TrimSpace(req.Faculty) == "" {
		fields["faculty"] = "Bắt buộc"
	}
	if strings.TrimSpace(req.DisplayName) == "" {
		fields["display_name"] = "Bắt buộc"
	}
	if len(fields) > 0 {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Vui lòng điền đủ thông tin xác minh.", fields)
		return
	}
	if me.Verification == "approved" {
		writeError(w, http.StatusConflict, "invalid_state", "Hồ sơ đã được duyệt.", nil)
		return
	}

	var updated Me
	err := s.db.QueryRow(r.Context(), `
		UPDATE users
		SET full_name = $2, student_code = $3, class_name = $4, faculty = $5,
		    display_name = $6, verification = 'pending', review_note = NULL
		WHERE id = $1 AND verification <> 'approved'
		RETURNING id, display_name, (verification = 'approved'), email, role, verification,
		          full_name, student_code, class_name, faculty, review_note
	`, me.ID, strings.TrimSpace(req.FullName), strings.TrimSpace(req.StudentCode),
		strings.TrimSpace(req.ClassName), strings.TrimSpace(req.Faculty), strings.TrimSpace(req.DisplayName)).Scan(
		&updated.ID, &updated.DisplayName, &updated.Verified, &updated.Email, &updated.Role, &updated.Verification,
		&updated.FullName, &updated.StudentCode, &updated.ClassName, &updated.Faculty, &updated.ReviewNote,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusConflict, "invalid_state", "Hồ sơ đã được duyệt.", nil)
		return
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể cập nhật hồ sơ.", nil)
		return
	}
	writeJSON(w, http.StatusOK, updated)
}

func (s *Server) handleAdminListVerifications(w http.ResponseWriter, r *http.Request, me Me) {
	statusFilter := r.URL.Query().Get("verification")
	if statusFilter == "" {
		statusFilter = "pending"
	}
	limit := parseLimit(r)
	offset := parseOffsetCursor(r)

	rows, err := s.db.Query(r.Context(), `
		SELECT id, display_name, (verification = 'approved'), email, role, verification,
		       full_name, student_code, class_name, faculty, review_note
		FROM users
		WHERE verification = $1
		ORDER BY created_at ASC, id ASC
		LIMIT $2 OFFSET $3
	`, statusFilter, limit+1, offset)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tải danh sách chờ duyệt.", nil)
		return
	}
	defer rows.Close()

	items := make([]Me, 0)
	for rows.Next() {
		var u Me
		if err := rows.Scan(&u.ID, &u.DisplayName, &u.Verified, &u.Email, &u.Role, &u.Verification,
			&u.FullName, &u.StudentCode, &u.ClassName, &u.Faculty, &u.ReviewNote); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi đọc dữ liệu.", nil)
			return
		}
		items = append(items, u)
	}
	var next *string
	if len(items) > limit {
		items = items[:limit]
		next = encodeOffsetCursor(offset + limit)
	}
	writeJSON(w, http.StatusOK, Page[Me]{Items: items, NextCursor: next})
}

func (s *Server) handleAdminReviewVerification(w http.ResponseWriter, r *http.Request, me Me) {
	userID := r.PathValue("user_id")
	rawBody, ok := readBodyAndDecode(w, r, &struct{}{})
	if !ok {
		return
	}
	var req struct {
		Decision string  `json:"decision"`
		Note     *string `json:"note"`
	}
	if err := json.Unmarshal(rawBody, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Dữ liệu không hợp lệ.", nil)
		return
	}
	if req.Decision != "approve" && req.Decision != "reject" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Quyết định phải là approve hoặc reject.", nil)
		return
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		newStatus := "approved"
		if req.Decision == "reject" {
			newStatus = "rejected"
		}
		var updated Me
		err := s.db.QueryRow(r.Context(), `
			UPDATE users
			SET verification = $2, review_note = $3, reviewed_by = $4, reviewed_at = $5
			WHERE id = $1
			RETURNING id, display_name, (verification = 'approved'), email, role, verification,
			          full_name, student_code, class_name, faculty, review_note
		`, userID, newStatus, req.Note, me.ID, s.now().UTC()).Scan(
			&updated.ID, &updated.DisplayName, &updated.Verified, &updated.Email, &updated.Role, &updated.Verification,
			&updated.FullName, &updated.StudentCode, &updated.ClassName, &updated.Faculty, &updated.ReviewNote,
		)
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy người dùng.", nil)
			return 0, nil, false
		}
		if pgErrCode(err) == "23505" {
			writeError(w, http.StatusConflict, "student_code_taken", "Mã sinh viên này đã thuộc về một tài khoản đã duyệt khác.", nil)
			return 0, nil, false
		}
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể cập nhật trạng thái duyệt.", nil)
			return 0, nil, false
		}
		return http.StatusOK, updated, true
	})
}
