package api

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var vnLoc = func() *time.Location {
	loc, err := time.LoadLocation("Asia/Ho_Chi_Minh")
	if err != nil {
		return time.FixedZone("ICT", 7*3600)
	}
	return loc
}()

type Config struct {
	SMTPHost              string
	SMTPPort              string
	SMTPFrom              string
	OTPPepper             string
	OTPCooldownSeconds    int
	S3Endpoint            string
	S3Bucket              string
	S3AccessKey           string
	S3SecretKey           string
	NotificationURL       string
	InternalServiceToken  string
}

type Server struct {
	db  *pgxpool.Pool
	cfg Config
	s3  *S3Client
	now func() time.Time
}

func NewServer(db *pgxpool.Pool, cfg Config) *Server {
	if cfg.OTPPepper == "" {
		cfg.OTPPepper = "dev-pepper"
	}
	return &Server{
		db:  db,
		cfg: cfg,
		s3:  NewS3Client(cfg.S3Endpoint, cfg.S3Bucket, cfg.S3AccessKey, cfg.S3SecretKey),
		now: time.Now,
	}
}

func (s *Server) SetClock(fn func() time.Time) {
	s.now = fn
}

func (s *Server) todayVN() time.Time {
	t := s.now().In(vnLoc)
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		if err := s.db.Ping(r.Context()); err != nil {
			writeError(w, http.StatusServiceUnavailable, "service_unavailable", "Database unavailable", nil)
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	// Auth & Verification
	mux.HandleFunc("POST /v1/auth/otp", s.handleSendOTP)
	mux.HandleFunc("POST /v1/auth/verify", s.handleVerifyOTP)
	mux.HandleFunc("POST /v1/auth/logout", s.auth(false, s.handleLogout))
	mux.HandleFunc("GET /v1/me", s.auth(false, s.handleGetMe))
	mux.HandleFunc("PUT /v1/me/verification", s.auth(false, s.handlePutVerification))
	mux.HandleFunc("GET /v1/admin/verifications", s.authAdmin(s.handleAdminListVerifications))
	mux.HandleFunc("POST /v1/admin/verifications/{user_id}/review", s.authAdmin(s.handleAdminReviewVerification))

	// Catalog & Listings
	mux.HandleFunc("GET /v1/catalog/options", s.auth(false, s.handleCatalogOptions))
	mux.HandleFunc("GET /v1/listings", s.auth(false, s.handleListListings))
	mux.HandleFunc("GET /v1/listings/{id}", s.auth(false, s.handleGetListing))
	mux.HandleFunc("POST /v1/listings", s.auth(true, s.handleCreateListing))
	mux.HandleFunc("PATCH /v1/listings/{id}", s.auth(true, s.handlePatchListing))
	mux.HandleFunc("GET /v1/listings/{id}/availability", s.auth(false, s.handleListingAvailability))
	mux.HandleFunc("GET /v1/listings/{id}/blocks", s.auth(true, s.handleListBlocks))
	mux.HandleFunc("POST /v1/listings/{id}/blocks", s.auth(true, s.handleCreateBlock))
	mux.HandleFunc("DELETE /v1/listings/{id}/blocks/{block_id}", s.auth(true, s.handleDeleteBlock))
	mux.HandleFunc("POST /v1/listings/{id}/quote", s.auth(false, s.handleQuoteListing))

	// Photos
	mux.HandleFunc("POST /v1/photos", s.auth(false, s.handleUploadPhoto))
	mux.HandleFunc("GET /v1/photos/{id}", s.auth(false, s.handleGetPhoto))

	// Orders
	mux.HandleFunc("POST /v1/orders", s.auth(true, s.handleCreateOrder))
	mux.HandleFunc("GET /v1/orders", s.auth(false, s.handleListOrders))
	mux.HandleFunc("GET /v1/orders/{id}", s.auth(false, s.handleGetOrder))
	mux.HandleFunc("POST /v1/orders/{id}/approve", s.auth(true, s.handleApproveOrder))
	mux.HandleFunc("POST /v1/orders/{id}/reject", s.auth(true, s.handleRejectOrder))
	mux.HandleFunc("POST /v1/orders/{id}/cancel", s.auth(true, s.handleCancelOrder))
	mux.HandleFunc("POST /v1/orders/{id}/pickup", s.auth(true, s.handlePickupOrder))
	mux.HandleFunc("POST /v1/orders/{id}/return", s.auth(true, s.handleReturnOrder))
	mux.HandleFunc("POST /v1/orders/{id}/deposit", s.auth(true, s.handleDepositOrder))
	mux.HandleFunc("GET /v1/orders/{id}/messages", s.auth(false, s.handleListMessages))
	mux.HandleFunc("POST /v1/orders/{id}/messages", s.auth(true, s.handleCreateMessage))

	// Cases & Fees
	mux.HandleFunc("POST /v1/cases", s.auth(true, s.handleCreateCase))
	mux.HandleFunc("GET /v1/cases", s.auth(false, s.handleListCases))
	mux.HandleFunc("GET /v1/cases/{id}", s.auth(false, s.handleGetCase))
	mux.HandleFunc("GET /v1/admin/cases", s.authAdmin(s.handleAdminListCases))
	mux.HandleFunc("POST /v1/admin/cases/{id}/resolve", s.authAdmin(s.handleAdminResolveCase))

	mux.HandleFunc("GET /v1/fees/summary", s.auth(false, s.handleFeesSummary))
	mux.HandleFunc("GET /v1/fees/entries", s.auth(false, s.handleFeesEntries))
	mux.HandleFunc("GET /v1/admin/fees/owners", s.authAdmin(s.handleAdminFeesOwners))
	mux.HandleFunc("GET /v1/admin/fees/owners/{id}/entries", s.authAdmin(s.handleAdminOwnerFeeEntries))
	mux.HandleFunc("POST /v1/admin/settlements", s.authAdmin(s.handleAdminCreateSettlement))
	mux.HandleFunc("GET /v1/settlements", s.auth(false, s.handleListSettlements))

	return mux
}

type authedHandler func(w http.ResponseWriter, r *http.Request, me Me)

func (s *Server) authenticate(r *http.Request) (Me, string, error) {
	hdr := r.Header.Get("Authorization")
	if !strings.HasPrefix(hdr, "Bearer ") {
		return Me{}, "", errors.New("missing bearer")
	}
	token := strings.TrimSpace(strings.TrimPrefix(hdr, "Bearer "))
	if token == "" {
		return Me{}, "", errors.New("empty token")
	}
	tokenHash := sha256Hex(token)
	var me Me
	var sessionID string
	err := s.db.QueryRow(r.Context(), `
		SELECT s.id, u.id, u.display_name, (u.verification = 'approved'), u.email, u.role, u.verification,
		       u.full_name, u.student_code, u.class_name, u.faculty, u.review_note
		FROM sessions s
		JOIN users u ON u.id = s.user_id
		WHERE s.token_hash = $1 AND s.revoked_at IS NULL AND s.expires_at > $2
	`, tokenHash, s.now().UTC()).Scan(
		&sessionID, &me.ID, &me.DisplayName, &me.Verified, &me.Email, &me.Role, &me.Verification,
		&me.FullName, &me.StudentCode, &me.ClassName, &me.Faculty, &me.ReviewNote,
	)
	if err != nil {
		return Me{}, "", err
	}
	return me, sessionID, nil
}

func (s *Server) auth(requireVerified bool, next authedHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		me, _, err := s.authenticate(r)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "unauthenticated", "Vui lòng đăng nhập lại.", nil)
			return
		}
		if requireVerified && me.Verification != "approved" {
			writeError(w, http.StatusForbidden, "verification_required", "Tài khoản cần được duyệt sinh viên trước khi thực hiện thao tác này.", nil)
			return
		}
		next(w, r, me)
	}
}

func (s *Server) authAdmin(next authedHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		me, _, err := s.authenticate(r)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "unauthenticated", "Vui lòng đăng nhập lại.", nil)
			return
		}
		if me.Role != "admin" {
			writeError(w, http.StatusForbidden, "forbidden", "Chỉ quản trị viên mới có quyền thực hiện thao tác này.", nil)
			return
		}
		next(w, r, me)
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if v != nil {
		if err := json.NewEncoder(w).Encode(v); err != nil {
			log.Printf("encode response error: %v", err)
		}
	}
}

func writeError(w http.ResponseWriter, status int, code, message string, fields map[string]string) {
	if fields == nil {
		fields = map[string]string{}
	}
	writeJSON(w, status, ErrorBody{
		Error: ErrorDetail{
			Code:    code,
			Message: message,
			Fields:  fields,
		},
	})
}

func readBodyAndDecode(w http.ResponseWriter, r *http.Request, dst any) ([]byte, bool) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Không đọc được dữ liệu gửi lên.", nil)
		return nil, false
	}
	if len(strings.TrimSpace(string(body))) == 0 {
		body = []byte("{}")
	}
	if err := json.Unmarshal(body, dst); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Dữ liệu JSON không hợp lệ.", nil)
		return nil, false
	}
	return body, true
}

// runIdempotent checks Idempotency-Key after permission checks, or executes fn and stores the 2xx response.
func (s *Server) runIdempotent(w http.ResponseWriter, r *http.Request, userID string, rawBody []byte, fn func() (int, any, bool)) {
	idemKey := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
	if idemKey == "" {
		writeError(w, http.StatusBadRequest, "invalid_request", "Thiếu header Idempotency-Key.", map[string]string{"Idempotency-Key": "Bắt buộc"})
		return
	}
	reqHash := sha256HexBytes(rawBody)
	path := r.URL.Path

	var storedHash string
	var storedStatus int
	var storedResp []byte
	err := s.db.QueryRow(r.Context(), `
		SELECT request_hash, status_code, response_body
		FROM idempotency_keys
		WHERE user_id = $1 AND method = $2 AND path = $3 AND idem_key = $4
	`, userID, r.Method, path, idemKey).Scan(&storedHash, &storedStatus, &storedResp)
	if err == nil {
		if storedHash != reqHash {
			writeError(w, http.StatusConflict, "idempotency_conflict", "Idempotency-Key đã được dùng với nội dung khác.", nil)
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.WriteHeader(storedStatus)
		_, _ = w.Write(storedResp)
		return
	} else if !errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi kiểm tra Idempotency-Key.", nil)
		return
	}

	status, payload, ok := fn()
	if !ok {
		return
	}
	respBytes, err := json.Marshal(payload)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tạo phản hồi.", nil)
		return
	}
	if status >= 200 && status < 300 {
		_, _ = s.db.Exec(r.Context(), `
			INSERT INTO idempotency_keys (user_id, method, path, idem_key, request_hash, status_code, response_body)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			ON CONFLICT DO NOTHING
		`, userID, r.Method, path, idemKey, reqHash, status, respBytes)
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_, _ = w.Write(respBytes)
}

func parseLimit(r *http.Request) int {
	limit := 20
	if raw := r.URL.Query().Get("limit"); raw != "" {
		if n, err := strconv.Atoi(raw); err == nil && n > 0 {
			limit = n
		}
	}
	if limit > 100 {
		limit = 100
	}
	return limit
}

func parseOffsetCursor(r *http.Request) int {
	raw := r.URL.Query().Get("cursor")
	if raw == "" {
		return 0
	}
	b, err := base64.RawURLEncoding.DecodeString(raw)
	if err != nil {
		return 0
	}
	n, err := strconv.Atoi(string(b))
	if err != nil || n < 0 {
		return 0
	}
	return n
}

func encodeOffsetCursor(offset int) *string {
	s := base64.RawURLEncoding.EncodeToString([]byte(strconv.Itoa(offset)))
	return &s
}

func newID(prefix string) string {
	var b [12]byte
	_, _ = rand.Read(b[:])
	return fmt.Sprintf("%s-%s", prefix, hex.EncodeToString(b[:]))
}

func randomToken() string {
	var b [32]byte
	_, _ = rand.Read(b[:])
	return base64.RawURLEncoding.EncodeToString(b[:])
}

func sha256Hex(s string) string {
	return sha256HexBytes([]byte(s))
}

func sha256HexBytes(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

func pgErrCode(err error) string {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return pgErr.Code
	}
	return ""
}

func parseDateStrict(s string) (time.Time, error) {
	return time.Parse("2006-01-02", s)
}
