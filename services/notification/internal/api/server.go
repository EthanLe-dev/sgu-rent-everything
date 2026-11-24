package api

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Config struct {
	InternalServiceToken string
}

type Server struct {
	db  *pgxpool.Pool
	cfg Config
	now func() time.Time
}

func NewServer(db *pgxpool.Pool, cfg Config) *Server {
	return &Server{
		db:  db,
		cfg: cfg,
		now: time.Now,
	}
}

type Notice struct {
	ID         string  `json:"id"`
	Type       string  `json:"type"`
	Title      string  `json:"title"`
	Body       string  `json:"body"`
	TargetType string  `json:"target_type"`
	TargetID   string  `json:"target_id"`
	ReadAt     *string `json:"read_at"`
	CreatedAt  string  `json:"created_at"`
}

type Page[T any] struct {
	Items      []T     `json:"items"`
	NextCursor *string `json:"next_cursor"`
}

var validEventTypes = []string{
	"order_requested", "order_approved", "order_closed",
	"pickup_confirmed", "return_due", "order_overdue",
	"return_confirmed", "case_opened", "case_resolved",
}

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		if err := s.db.Ping(r.Context()); err != nil {
			writeError(w, http.StatusServiceUnavailable, "service_unavailable", "Database unavailable")
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	mux.HandleFunc("POST /internal/v1/events", s.handleInternalEvent)
	mux.HandleFunc("PUT /v1/me/devices/{installation_id}", s.auth(s.handleUpsertDevice))
	mux.HandleFunc("DELETE /v1/me/devices/{installation_id}", s.auth(s.handleDeleteDevice))
	mux.HandleFunc("GET /v1/notifications", s.auth(s.handleListNotifications))
	mux.HandleFunc("PUT /v1/notifications/{id}/read", s.auth(s.handleReadNotification))
	return mux
}

func (s *Server) authenticate(r *http.Request) (string, error) {
	hdr := r.Header.Get("Authorization")
	if !strings.HasPrefix(hdr, "Bearer ") {
		return "", errors.New("missing bearer")
	}
	token := strings.TrimSpace(strings.TrimPrefix(hdr, "Bearer "))
	if token == "" {
		return "", errors.New("empty token")
	}
	sum := sha256.Sum256([]byte(token))
	tokenHash := hex.EncodeToString(sum[:])
	var userID string
	err := s.db.QueryRow(r.Context(), `
		SELECT user_id FROM sessions
		WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > $2
	`, tokenHash, s.now().UTC()).Scan(&userID)
	return userID, err
}

func (s *Server) auth(next func(http.ResponseWriter, *http.Request, string)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		uid, err := s.authenticate(r)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "unauthenticated", "Vui lòng đăng nhập lại.")
			return
		}
		next(w, r, uid)
	}
}

func (s *Server) handleInternalEvent(w http.ResponseWriter, r *http.Request) {
	hdr := r.Header.Get("Authorization")
	token := strings.TrimSpace(strings.TrimPrefix(hdr, "Bearer "))
	if !strings.HasPrefix(hdr, "Bearer ") || subtle.ConstantTimeCompare([]byte(token), []byte(s.cfg.InternalServiceToken)) != 1 {
		writeError(w, http.StatusUnauthorized, "unauthenticated", "Invalid service token")
		return
	}

	var req struct {
		EventID      string   `json:"event_id"`
		Type         string   `json:"type"`
		OccurredAt   string   `json:"occurred_at"`
		TargetType   string   `json:"target_type"`
		TargetID     string   `json:"target_id"`
		RecipientIDs []string `json:"recipient_ids"`
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil || json.Unmarshal(body, &req) != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Invalid JSON")
		return
	}
	if req.EventID == "" || !slices.Contains(validEventTypes, req.Type) ||
		(req.TargetType != "order" && req.TargetType != "case") || req.TargetID == "" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Invalid event payload")
		return
	}
	occAt, err := time.Parse(time.RFC3339, req.OccurredAt)
	if err != nil {
		occAt = s.now().UTC()
	}

	title, msgBody := renderVietnameseNotice(req.Type)

	tx, err := s.db.Begin(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "DB error")
		return
	}
	defer tx.Rollback(r.Context())

	if _, err := tx.Exec(r.Context(), `
		INSERT INTO inbox_events (event_id, received_at)
		VALUES ($1, $2)
		ON CONFLICT (event_id) DO NOTHING
	`, req.EventID, s.now().UTC()); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Failed to save inbox")
		return
	}

	for _, uid := range req.RecipientIDs {
		if uid == "" {
			continue
		}
		if _, err := tx.Exec(r.Context(), `
			INSERT INTO notifications (id, user_id, event_id, type, title, body, target_type, target_id, created_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
			ON CONFLICT (event_id, user_id) DO NOTHING
		`, newID("ntf"), uid, req.EventID, req.Type, title, msgBody, req.TargetType, req.TargetID, occAt.UTC()); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Failed to save notification")
			return
		}
	}

	if err := tx.Commit(r.Context()); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Commit failed")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func renderVietnameseNotice(eventType string) (string, string) {
	switch eventType {
	case "order_requested":
		return "Có yêu cầu thuê mới", "Một sinh viên vừa gửi yêu cầu thuê món đồ của bạn."
	case "order_approved":
		return "Đơn thuê đã được duyệt", "Chủ đồ đã duyệt yêu cầu thuê. Vui lòng hẹn giờ giao nhận."
	case "order_closed":
		return "Đơn thuê đã đóng", "Một đơn thuê của bạn đã được đóng hoặc từ chối."
	case "pickup_confirmed":
		return "Cập nhật bàn giao đồ", "Có xác nhận bàn giao mới cho đơn thuê của bạn."
	case "return_due":
		return "Sắp đến hạn trả đồ", "Đơn thuê của bạn sắp đến hạn trả hôm nay."
	case "order_overdue":
		return "Đơn thuê đã quá hạn", "Món đồ đã quá hạn trả, vui lòng kiểm tra và liên hệ xử lý."
	case "return_confirmed":
		return "Cập nhật trả đồ", "Có xác nhận trả đồ mới cho đơn thuê của bạn."
	case "case_opened":
		return "Có vụ việc mới", "Một vụ việc liên quan vừa được mở để xem xét."
	case "case_resolved":
		return "Vụ việc đã được xử lý", "Quản trị viên đã cập nhật kết quả xử lý vụ việc."
	default:
		return "Thông báo mới", "Bạn có cập nhật mới trong ứng dụng."
	}
}

func (s *Server) handleUpsertDevice(w http.ResponseWriter, r *http.Request, userID string) {
	instID := r.PathValue("installation_id")
	var req struct {
		FCMToken string `json:"fcm_token"`
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<16))
	if err != nil || json.Unmarshal(body, &req) != nil || strings.TrimSpace(req.FCMToken) == "" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Thiếu fcm_token.")
		return
	}
	_, err = s.db.Exec(r.Context(), `
		INSERT INTO device_installations (installation_id, user_id, fcm_token, updated_at)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (installation_id) DO UPDATE
		SET user_id = EXCLUDED.user_id, fcm_token = EXCLUDED.fcm_token, updated_at = EXCLUDED.updated_at
	`, instID, userID, strings.TrimSpace(req.FCMToken), s.now().UTC())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể lưu thiết bị.")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleDeleteDevice(w http.ResponseWriter, r *http.Request, userID string) {
	instID := r.PathValue("installation_id")
	_, _ = s.db.Exec(r.Context(), `DELETE FROM device_installations WHERE installation_id = $1 AND user_id = $2`, instID, userID)
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleListNotifications(w http.ResponseWriter, r *http.Request, userID string) {
	limit := 20
	if raw := r.URL.Query().Get("limit"); raw != "" {
		if n, err := strconv.Atoi(raw); err == nil && n > 0 && n <= 100 {
			limit = n
		}
	}
	offset := 0
	if raw := r.URL.Query().Get("cursor"); raw != "" {
		if b, err := base64.RawURLEncoding.DecodeString(raw); err == nil {
			if n, err := strconv.Atoi(string(b)); err == nil && n >= 0 {
				offset = n
			}
		}
	}

	rows, err := s.db.Query(r.Context(), `
		SELECT id, type, title, body, target_type, target_id, read_at, created_at
		FROM notifications
		WHERE user_id = $1
		ORDER BY created_at DESC, id DESC
		LIMIT $2 OFFSET $3
	`, userID, limit+1, offset)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tải thông báo.")
		return
	}
	defer rows.Close()

	items := make([]Notice, 0)
	for rows.Next() {
		var n Notice
		var readAt *time.Time
		var createdAt time.Time
		if err := rows.Scan(&n.ID, &n.Type, &n.Title, &n.Body, &n.TargetType, &n.TargetID, &readAt, &createdAt); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi đọc thông báo.")
			return
		}
		if readAt != nil {
			s := readAt.UTC().Format(time.RFC3339)
			n.ReadAt = &s
		}
		n.CreatedAt = createdAt.UTC().Format(time.RFC3339)
		items = append(items, n)
	}
	var next *string
	if len(items) > limit {
		items = items[:limit]
		enc := base64.RawURLEncoding.EncodeToString([]byte(strconv.Itoa(offset + limit)))
		next = &enc
	}
	writeJSON(w, http.StatusOK, Page[Notice]{Items: items, NextCursor: next})
}

func (s *Server) handleReadNotification(w http.ResponseWriter, r *http.Request, userID string) {
	id := r.PathValue("id")
	var n Notice
	var readAt *time.Time
	var createdAt time.Time
	err := s.db.QueryRow(r.Context(), `
		UPDATE notifications
		SET read_at = COALESCE(read_at, $3)
		WHERE id = $1 AND user_id = $2
		RETURNING id, type, title, body, target_type, target_id, read_at, created_at
	`, id, userID, s.now().UTC()).Scan(&n.ID, &n.Type, &n.Title, &n.Body, &n.TargetType, &n.TargetID, &readAt, &createdAt)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy thông báo.")
		return
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể cập nhật thông báo.")
		return
	}
	if readAt != nil {
		s := readAt.UTC().Format(time.RFC3339)
		n.ReadAt = &s
	}
	n.CreatedAt = createdAt.UTC().Format(time.RFC3339)
	writeJSON(w, http.StatusOK, n)
}

func newID(prefix string) string {
	var b [12]byte
	_, _ = rand.Read(b[:])
	return fmt.Sprintf("%s-%s", prefix, hex.EncodeToString(b[:]))
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]any{
		"error": map[string]any{
			"code":    code,
			"message": message,
			"fields":  map[string]string{},
		},
	})
}
