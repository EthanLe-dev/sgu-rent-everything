package api

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

const maxPhotoBytes = 8 * 1024 * 1024

type S3Client struct {
	endpoint  string
	bucket    string
	accessKey string
	secretKey string
	http      *http.Client
}

func NewS3Client(endpoint, bucket, accessKey, secretKey string) *S3Client {
	return &S3Client{
		endpoint:  strings.TrimRight(endpoint, "/"),
		bucket:    bucket,
		accessKey: accessKey,
		secretKey: secretKey,
		http:      &http.Client{Timeout: 15 * time.Second},
	}
}

func (c *S3Client) EnsureBucket(ctx context.Context) error {
	if c.endpoint == "" {
		return nil
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, c.endpoint+"/"+c.bucket, nil)
	if err != nil {
		return err
	}
	c.sign(req, nil)
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 200 && resp.StatusCode < 300 || resp.StatusCode == http.StatusConflict {
		return nil
	}
	return fmt.Errorf("s3 create bucket status %d", resp.StatusCode)
}

func (c *S3Client) PutObject(ctx context.Context, key, contentType string, data []byte) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, c.endpoint+"/"+c.bucket+"/"+key, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", contentType)
	c.sign(req, data)
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("s3 put status %d", resp.StatusCode)
	}
	return nil
}

func (c *S3Client) GetObject(ctx context.Context, key string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.endpoint+"/"+c.bucket+"/"+key, nil)
	if err != nil {
		return nil, err
	}
	c.sign(req, nil)
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("s3 get status %d", resp.StatusCode)
	}
	return io.ReadAll(resp.Body)
}

func (c *S3Client) sign(req *http.Request, payload []byte) {
	if c.accessKey == "" || c.secretKey == "" {
		return
	}
	now := time.Now().UTC()
	amzDate := now.Format("20060102T150405Z")
	dateStamp := now.Format("20060102")
	payloadHash := sha256HexBytes(payload)

	req.Header.Set("x-amz-date", amzDate)
	req.Header.Set("x-amz-content-sha256", payloadHash)
	if req.Header.Get("Host") == "" {
		req.Header.Set("Host", req.URL.Host)
	}

	headers := map[string]string{
		"host":                 req.URL.Host,
		"x-amz-content-sha256": payloadHash,
		"x-amz-date":           amzDate,
	}
	var keys []string
	for k := range headers {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var canonHeaders strings.Builder
	for _, k := range keys {
		canonHeaders.WriteString(k + ":" + headers[k] + "\n")
	}
	signedHeaders := strings.Join(keys, ";")

	canonReq := strings.Join([]string{
		req.Method,
		req.URL.EscapedPath(),
		req.URL.RawQuery,
		canonHeaders.String(),
		signedHeaders,
		payloadHash,
	}, "\n")

	scope := dateStamp + "/us-east-1/s3/aws4_request"
	stringToSign := strings.Join([]string{
		"AWS4-HMAC-SHA256",
		amzDate,
		scope,
		sha256Hex(canonReq),
	}, "\n")

	kDate := hmacSHA256([]byte("AWS4"+c.secretKey), dateStamp)
	kRegion := hmacSHA256(kDate, "us-east-1")
	kService := hmacSHA256(kRegion, "s3")
	kSigning := hmacSHA256(kService, "aws4_request")
	sig := hex.EncodeToString(hmacSHA256(kSigning, stringToSign))

	req.Header.Set("Authorization", fmt.Sprintf(
		"AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s",
		c.accessKey, scope, signedHeaders, sig,
	))
}

func hmacSHA256(key []byte, data string) []byte {
	mac := hmac.New(sha256.New, key)
	mac.Write([]byte(data))
	return mac.Sum(nil)
}

func (s *Server) handleUploadPhoto(w http.ResponseWriter, r *http.Request, me Me) {
	r.Body = http.MaxBytesReader(w, r.Body, maxPhotoBytes+1024*64)
	if err := r.ParseMultipartForm(maxPhotoBytes + 1024*64); err != nil {
		var maxErr *http.MaxBytesError
		if errors.As(err, &maxErr) {
			writeError(w, http.StatusRequestEntityTooLarge, "file_too_large", "Ảnh vượt quá giới hạn 8 MiB.", nil)
			return
		}
		writeError(w, http.StatusBadRequest, "invalid_request", "Dữ liệu multipart không hợp lệ.", nil)
		return
	}

	purpose := strings.TrimSpace(r.FormValue("purpose"))
	if purpose != "listing" && purpose != "handover" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "purpose phải là listing hoặc handover.", map[string]string{"purpose": "Không hợp lệ"})
		return
	}

	var orderID *string
	if purpose == "handover" {
		oid := strings.TrimSpace(r.FormValue("order_id"))
		if oid == "" {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Ảnh bàn giao bắt buộc có order_id.", map[string]string{"order_id": "Bắt buộc"})
			return
		}
		var ownerID, renterID string
		err := s.db.QueryRow(r.Context(), `SELECT owner_id, renter_id FROM orders WHERE id = $1`, oid).Scan(&ownerID, &renterID)
		if errors.Is(err, pgx.ErrNoRows) || (err == nil && ownerID != me.ID && renterID != me.ID) {
			writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
			return
		} else if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi kiểm tra đơn thuê.", nil)
			return
		}
		orderID = &oid
	}

	file, _, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Thiếu tệp ảnh.", map[string]string{"file": "Bắt buộc"})
		return
	}
	defer file.Close()

	data, err := io.ReadAll(io.LimitReader(file, maxPhotoBytes+1))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Không đọc được tệp ảnh.", nil)
		return
	}
	if len(data) > maxPhotoBytes {
		writeError(w, http.StatusRequestEntityTooLarge, "file_too_large", "Ảnh vượt quá giới hạn 8 MiB.", nil)
		return
	}

	ct := http.DetectContentType(data)
	if ct != "image/jpeg" && ct != "image/png" {
		writeError(w, http.StatusUnsupportedMediaType, "unsupported_media", "Chỉ hỗ trợ ảnh JPEG hoặc PNG.", nil)
		return
	}

	photoID := newID("photo")
	ext := "jpg"
	if ct == "image/png" {
		ext = "png"
	}
	s3Key := fmt.Sprintf("%s/%s.%s", purpose, photoID, ext)

	if err := s.s3.PutObject(r.Context(), s3Key, ct, data); err != nil {
		writeError(w, http.StatusServiceUnavailable, "service_unavailable", "Không thể lưu ảnh vào kho lưu trữ.", nil)
		return
	}

	if _, err := s.db.Exec(r.Context(), `
		INSERT INTO photos (id, uploader_id, purpose, order_id, s3_key, content_type, size_bytes)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, photoID, me.ID, purpose, orderID, s3Key, ct, len(data)); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể lưu thông tin ảnh.", nil)
		return
	}

	writeJSON(w, http.StatusCreated, map[string]string{"id": photoID})
}

func (s *Server) handleGetPhoto(w http.ResponseWriter, r *http.Request, me Me) {
	photoID := r.PathValue("id")
	var uploaderID, purpose, s3Key, contentType string
	var orderID, listingID *string
	err := s.db.QueryRow(r.Context(), `
		SELECT uploader_id, purpose, order_id, listing_id, s3_key, content_type
		FROM photos WHERE id = $1
	`, photoID).Scan(&uploaderID, &purpose, &orderID, &listingID, &s3Key, &contentType)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy ảnh.", nil)
		return
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tải ảnh.", nil)
		return
	}

	allowed := false
	switch purpose {
	case "listing":
		allowed = listingID != nil || uploaderID == me.ID
	case "handover":
		if orderID != nil {
			var ownerID, renterID string
			if err := s.db.QueryRow(r.Context(), `SELECT owner_id, renter_id FROM orders WHERE id = $1`, *orderID).Scan(&ownerID, &renterID); err == nil {
				if ownerID == me.ID || renterID == me.ID {
					allowed = true
				} else if me.Role == "admin" {
					var hasCase bool
					_ = s.db.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM cases WHERE target_type='order' AND target_id=$1)`, *orderID).Scan(&hasCase)
					allowed = hasCase
				}
			}
		}
	}

	if !allowed {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy ảnh.", nil)
		return
	}

	data, err := s.s3.GetObject(r.Context(), s3Key)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "service_unavailable", "Không thể đọc ảnh từ kho lưu trữ.", nil)
		return
	}
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Cache-Control", "private, max-age=300")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}
