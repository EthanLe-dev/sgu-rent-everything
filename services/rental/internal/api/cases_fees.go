package api

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"slices"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

var validCaseCategories = []string{
	"listing_content", "description", "accessory", "damage",
	"overdue", "deposit", "handover", "other",
}

func (s *Server) getCaseByID(ctx context.Context, id string) (Case, error) {
	var c Case
	var ts time.Time
	err := s.db.QueryRow(ctx, `
		SELECT id, target_type, target_id, reporter_id, category, detail, status, resolution, created_at
		FROM cases WHERE id = $1
	`, id).Scan(&c.ID, &c.TargetType, &c.TargetID, &c.ReporterID, &c.Category, &c.Detail, &c.Status, &c.Resolution, &ts)
	if err != nil {
		return Case{}, err
	}
	c.CreatedAt = formatTS(ts)
	return c, nil
}

func (s *Server) handleCreateCase(w http.ResponseWriter, r *http.Request, me Me) {
	var req struct {
		TargetType string `json:"target_type"`
		TargetID   string `json:"target_id"`
		Category   string `json:"category"`
		Detail     string `json:"detail"`
	}
	rawBody, ok := readBodyAndDecode(w, r, &req)
	if !ok {
		return
	}
	if req.TargetType != "listing" && req.TargetType != "order" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "target_type phải là listing hoặc order.", nil)
		return
	}
	if !slices.Contains(validCaseCategories, req.Category) {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Loại vụ việc không hợp lệ.", nil)
		return
	}
	if strings.TrimSpace(req.Detail) == "" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Cần mô tả chi tiết vụ việc.", nil)
		return
	}

	var recipients []string
	if req.TargetType == "order" {
		ownerID, renterID, viewOK := s.canViewOrder(r.Context(), req.TargetID, me)
		if !viewOK || (me.ID != ownerID && me.ID != renterID) {
			writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
			return
		}
		recipients = []string{ownerID, renterID}
	} else {
		var ownerID string
		if err := s.db.QueryRow(r.Context(), `SELECT owner_id FROM listings WHERE id = $1`, req.TargetID).Scan(&ownerID); err != nil {
			writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy món đồ.", nil)
			return
		}
		recipients = []string{ownerID}
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		tx, err := s.db.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
			return 0, nil, false
		}
		defer tx.Rollback(r.Context())

		if req.Category == "handover" {
			if req.TargetType != "order" {
				writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Vụ việc bàn giao chỉ áp dụng cho đơn thuê.", nil)
				return 0, nil, false
			}
			var status string
			if err := tx.QueryRow(r.Context(), `SELECT status FROM orders WHERE id = $1 FOR UPDATE`, req.TargetID).Scan(&status); err != nil {
				writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
				return 0, nil, false
			}
			var pickupCount int
			_ = tx.QueryRow(r.Context(), `SELECT COUNT(*) FROM order_confirmations WHERE order_id = $1 AND kind = 'pickup'`, req.TargetID).Scan(&pickupCount)
			if status != "approved" || pickupCount != 1 {
				writeError(w, http.StatusConflict, "invalid_state", "Chỉ mở vụ việc bàn giao khi đơn đang chờ giao và có đúng một xác nhận.", nil)
				return 0, nil, false
			}
		}

		caseID := newID("case")
		now := s.now().UTC()
		_, err = tx.Exec(r.Context(), `
			INSERT INTO cases (id, target_type, target_id, reporter_id, category, detail, status, created_at)
			VALUES ($1, $2, $3, $4, $5, $6, 'open', $7)
		`, caseID, req.TargetType, req.TargetID, me.ID, req.Category, strings.TrimSpace(req.Detail), now)
		if err != nil {
			if pgErrCode(err) == "23505" {
				writeError(w, http.StatusConflict, "invalid_state", "Đơn này đã có vụ việc bàn giao đang mở.", nil)
				return 0, nil, false
			}
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tạo vụ việc.", nil)
			return 0, nil, false
		}
		if err := s.insertOutbox(r.Context(), tx, "case_opened", "case", caseID, recipients); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tạo thông báo.", nil)
			return 0, nil, false
		}
		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi lưu vụ việc.", nil)
			return 0, nil, false
		}
		c, _ := s.getCaseByID(r.Context(), caseID)
		return http.StatusCreated, c, true
	})
}

func (s *Server) handleListCases(w http.ResponseWriter, r *http.Request, me Me) {
	limit := parseLimit(r)
	offset := parseOffsetCursor(r)

	var rows pgx.Rows
	var err error
	if me.Role == "admin" {
		rows, err = s.db.Query(r.Context(), `
			SELECT id, target_type, target_id, reporter_id, category, detail, status, resolution, created_at
			FROM cases
			ORDER BY created_at DESC, id DESC
			LIMIT $1 OFFSET $2
		`, limit+1, offset)
	} else {
		rows, err = s.db.Query(r.Context(), `
			SELECT c.id, c.target_type, c.target_id, c.reporter_id, c.category, c.detail, c.status, c.resolution, c.created_at
			FROM cases c
			LEFT JOIN orders o ON c.target_type = 'order' AND o.id = c.target_id
			WHERE c.reporter_id = $1 OR o.owner_id = $1 OR o.renter_id = $1
			ORDER BY c.created_at DESC, c.id DESC
			LIMIT $2 OFFSET $3
		`, me.ID, limit+1, offset)
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tải danh sách vụ việc.", nil)
		return
	}
	defer rows.Close()

	items := make([]Case, 0)
	for rows.Next() {
		var c Case
		var ts time.Time
		if err := rows.Scan(&c.ID, &c.TargetType, &c.TargetID, &c.ReporterID, &c.Category, &c.Detail, &c.Status, &c.Resolution, &ts); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi đọc dữ liệu.", nil)
			return
		}
		c.CreatedAt = formatTS(ts)
		items = append(items, c)
	}
	var next *string
	if len(items) > limit {
		items = items[:limit]
		next = encodeOffsetCursor(offset + limit)
	}
	writeJSON(w, http.StatusOK, Page[Case]{Items: items, NextCursor: next})
}

func (s *Server) handleGetCase(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	c, err := s.getCaseByID(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy vụ việc.", nil)
		return
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
		return
	}

	if me.Role != "admin" && c.ReporterID != me.ID {
		allowed := false
		if c.TargetType == "order" {
			ownerID, renterID, ok := s.canViewOrder(r.Context(), c.TargetID, me)
			allowed = ok && (me.ID == ownerID || me.ID == renterID)
		}
		if !allowed {
			writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy vụ việc.", nil)
			return
		}
	}
	writeJSON(w, http.StatusOK, c)
}

func (s *Server) handleAdminListCases(w http.ResponseWriter, r *http.Request, me Me) {
	var args []any
	var where []string
	if st := strings.TrimSpace(r.URL.Query().Get("status")); st != "" {
		args = append(args, st)
		where = append(where, fmt.Sprintf("status = $%d", len(args)))
	}
	if tt := strings.TrimSpace(r.URL.Query().Get("target_type")); tt != "" {
		args = append(args, tt)
		where = append(where, fmt.Sprintf("target_type = $%d", len(args)))
	}
	whereSQL := ""
	if len(where) > 0 {
		whereSQL = "WHERE " + strings.Join(where, " AND ")
	}
	limit := parseLimit(r)
	offset := parseOffsetCursor(r)
	args = append(args, limit+1, offset)

	rows, err := s.db.Query(r.Context(), fmt.Sprintf(`
		SELECT id, target_type, target_id, reporter_id, category, detail, status, resolution, created_at
		FROM cases %s
		ORDER BY created_at DESC, id DESC
		LIMIT $%d OFFSET $%d
	`, whereSQL, len(args)-1, len(args)), args...)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tải vụ việc.", nil)
		return
	}
	defer rows.Close()

	items := make([]Case, 0)
	for rows.Next() {
		var c Case
		var ts time.Time
		if err := rows.Scan(&c.ID, &c.TargetType, &c.TargetID, &c.ReporterID, &c.Category, &c.Detail, &c.Status, &c.Resolution, &ts); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi đọc dữ liệu.", nil)
			return
		}
		c.CreatedAt = formatTS(ts)
		items = append(items, c)
	}
	var next *string
	if len(items) > limit {
		items = items[:limit]
		next = encodeOffsetCursor(offset + limit)
	}
	writeJSON(w, http.StatusOK, Page[Case]{Items: items, NextCursor: next})
}

func (s *Server) handleAdminResolveCase(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	var req struct {
		Resolution      string  `json:"resolution"`
		Refunded        *int    `json:"refunded"`
		HandoverOutcome *string `json:"handover_outcome"`
	}
	rawBody, ok := readBodyAndDecode(w, r, &req)
	if !ok {
		return
	}
	if strings.TrimSpace(req.Resolution) == "" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Cần nhập kết quả xử lý.", nil)
		return
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		tx, err := s.db.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
			return 0, nil, false
		}
		defer tx.Rollback(r.Context())

		var targetType, targetID, reporterID, category, status string
		err = tx.QueryRow(r.Context(), `
			SELECT target_type, target_id, reporter_id, category, status
			FROM cases WHERE id = $1 FOR UPDATE
		`, id).Scan(&targetType, &targetID, &reporterID, &category, &status)
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy vụ việc.", nil)
			return 0, nil, false
		} else if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
			return 0, nil, false
		}
		if status != "open" {
			writeError(w, http.StatusConflict, "invalid_state", "Vụ việc đã được xử lý.", nil)
			return 0, nil, false
		}

		recipients := []string{reporterID}
		if targetType == "order" {
			var ownerID, renterID, oStatus, depStatus string
			var deposit int
			err = tx.QueryRow(r.Context(), `
				SELECT owner_id, renter_id, status, deposit_status, deposit
				FROM orders WHERE id = $1 FOR UPDATE
			`, targetID).Scan(&ownerID, &renterID, &oStatus, &depStatus, &deposit)
			if err != nil {
				writeError(w, http.StatusInternalServerError, "internal_error", "Không tìm thấy đơn liên quan.", nil)
				return 0, nil, false
			}
			recipients = []string{ownerID, renterID}

			if category == "deposit" && oStatus == "returned" && depStatus == "disputed" {
				if req.Refunded == nil || *req.Refunded < 0 || *req.Refunded > deposit {
					writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Số tiền hoàn cọc không hợp lệ.", map[string]string{"refunded": "Phải từ 0 đến tiền cọc"})
					return 0, nil, false
				}
				if _, err := tx.Exec(r.Context(), `
					UPDATE orders
					SET deposit_status = 'resolved', deposit_refunded = $2, deposit_reason = $3, status = 'completed'
					WHERE id = $1
				`, targetID, *req.Refunded, strings.TrimSpace(req.Resolution)); err != nil {
					writeError(w, http.StatusInternalServerError, "internal_error", "Không thể cập nhật kết quả cọc.", nil)
					return 0, nil, false
				}
			}

			if category == "handover" {
				if req.HandoverOutcome == nil || (*req.HandoverOutcome != "resume" && *req.HandoverOutcome != "cancel_unhanded") {
					writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Cần chọn handover_outcome là resume hoặc cancel_unhanded.", nil)
					return 0, nil, false
				}
				if *req.HandoverOutcome == "cancel_unhanded" {
					if _, err := tx.Exec(r.Context(), `
						UPDATE orders SET status = 'cancelled', close_reason = $2 WHERE id = $1
					`, targetID, strings.TrimSpace(req.Resolution)); err != nil {
						writeError(w, http.StatusInternalServerError, "internal_error", "Không thể đóng đơn.", nil)
						return 0, nil, false
					}
					_, _ = tx.Exec(r.Context(), `DELETE FROM listing_schedule_locks WHERE order_id = $1`, targetID)
				}
			}
		}

		now := s.now().UTC()
		if _, err := tx.Exec(r.Context(), `
			UPDATE cases SET status = 'resolved', resolution = $2, resolved_by = $3, resolved_at = $4
			WHERE id = $1
		`, id, strings.TrimSpace(req.Resolution), me.ID, now); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể cập nhật vụ việc.", nil)
			return 0, nil, false
		}
		if err := s.insertOutbox(r.Context(), tx, "case_resolved", "case", id, recipients); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tạo thông báo.", nil)
			return 0, nil, false
		}
		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi lưu kết quả.", nil)
			return 0, nil, false
		}
		c, _ := s.getCaseByID(r.Context(), id)
		return http.StatusOK, c, true
	})
}

func (s *Server) queryFeeSummary(ctx context.Context, ownerID string) (FeeSummary, error) {
	var fs FeeSummary
	err := s.db.QueryRow(ctx, `
		SELECT
			COALESCE(SUM(amount), 0),
			COALESCE(SUM(amount) FILTER (WHERE state = 'settled'), 0),
			COALESCE(SUM(amount) FILTER (WHERE state = 'outstanding'), 0)
		FROM fee_ledger
		WHERE owner_id = $1
	`, ownerID).Scan(&fs.Accrued, &fs.Settled, &fs.Outstanding)
	return fs, err
}

func (s *Server) queryFeeEntries(ctx context.Context, ownerID, state string, limit, offset int) (Page[FeeEntry], error) {
	args := []any{ownerID}
	where := "owner_id = $1"
	if state != "" {
		args = append(args, state)
		where += fmt.Sprintf(" AND state = $%d", len(args))
	}
	args = append(args, limit+1, offset)
	rows, err := s.db.Query(ctx, fmt.Sprintf(`
		SELECT
			order_id,
			MIN(accrued_at) AS accrued_at,
			COALESCE(SUM(amount) FILTER (WHERE payer_role = 'renter'), 0) AS renter_fee,
			COALESCE(SUM(amount) FILTER (WHERE payer_role = 'owner'), 0) AS owner_fee,
			COALESCE(SUM(amount), 0) AS total,
			MIN(state) AS state,
			MIN(settlement_id) AS settlement_id
		FROM fee_ledger
		WHERE %s
		GROUP BY order_id
		ORDER BY MIN(accrued_at) DESC, order_id DESC
		LIMIT $%d OFFSET $%d
	`, where, len(args)-1, len(args)), args...)
	if err != nil {
		return Page[FeeEntry]{}, err
	}
	defer rows.Close()

	items := make([]FeeEntry, 0)
	for rows.Next() {
		var fe FeeEntry
		var ts time.Time
		if err := rows.Scan(&fe.OrderID, &ts, &fe.RenterFee, &fe.OwnerFee, &fe.Total, &fe.State, &fe.SettlementID); err != nil {
			return Page[FeeEntry]{}, err
		}
		fe.AccruedAt = formatTS(ts)
		items = append(items, fe)
	}
	var next *string
	if len(items) > limit {
		items = items[:limit]
		next = encodeOffsetCursor(offset + limit)
	}
	return Page[FeeEntry]{Items: items, NextCursor: next}, nil
}

func (s *Server) handleFeesSummary(w http.ResponseWriter, r *http.Request, me Me) {
	fs, err := s.queryFeeSummary(r.Context(), me.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tải tổng hợp phí.", nil)
		return
	}
	writeJSON(w, http.StatusOK, fs)
}

func (s *Server) handleFeesEntries(w http.ResponseWriter, r *http.Request, me Me) {
	p, err := s.queryFeeEntries(r.Context(), me.ID, strings.TrimSpace(r.URL.Query().Get("state")), parseLimit(r), parseOffsetCursor(r))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tải chi tiết phí.", nil)
		return
	}
	writeJSON(w, http.StatusOK, p)
}

func (s *Server) handleAdminFeesOwners(w http.ResponseWriter, r *http.Request, me Me) {
	limit := parseLimit(r)
	offset := parseOffsetCursor(r)
	rows, err := s.db.Query(r.Context(), `
		SELECT u.id, u.display_name, (u.verification = 'approved'),
		       COALESCE(SUM(f.amount), 0),
		       COALESCE(SUM(f.amount) FILTER (WHERE f.state = 'settled'), 0),
		       COALESCE(SUM(f.amount) FILTER (WHERE f.state = 'outstanding'), 0)
		FROM fee_ledger f
		JOIN users u ON u.id = f.owner_id
		GROUP BY u.id, u.display_name, u.verification
		ORDER BY COALESCE(SUM(f.amount) FILTER (WHERE f.state = 'outstanding'), 0) DESC, u.id ASC
		LIMIT $1 OFFSET $2
	`, limit+1, offset)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tải danh sách phí chủ đồ.", nil)
		return
	}
	defer rows.Close()

	items := make([]OwnerFees, 0)
	for rows.Next() {
		var of OwnerFees
		if err := rows.Scan(&of.Owner.ID, &of.Owner.DisplayName, &of.Owner.Verified,
			&of.Summary.Accrued, &of.Summary.Settled, &of.Summary.Outstanding); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi đọc dữ liệu.", nil)
			return
		}
		items = append(items, of)
	}
	var next *string
	if len(items) > limit {
		items = items[:limit]
		next = encodeOffsetCursor(offset + limit)
	}
	writeJSON(w, http.StatusOK, Page[OwnerFees]{Items: items, NextCursor: next})
}

func (s *Server) handleAdminOwnerFeeEntries(w http.ResponseWriter, r *http.Request, me Me) {
	ownerID := r.PathValue("id")
	p, err := s.queryFeeEntries(r.Context(), ownerID, strings.TrimSpace(r.URL.Query().Get("state")), parseLimit(r), parseOffsetCursor(r))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tải chi tiết phí.", nil)
		return
	}
	writeJSON(w, http.StatusOK, p)
}

func (s *Server) handleAdminCreateSettlement(w http.ResponseWriter, r *http.Request, me Me) {
	var req struct {
		OwnerID        string   `json:"owner_id"`
		OrderIDs       []string `json:"order_ids"`
		ReceivedAmount *int     `json:"received_amount"`
		Reference      string   `json:"reference"`
	}
	rawBody, ok := readBodyAndDecode(w, r, &req)
	if !ok {
		return
	}
	if strings.TrimSpace(req.OwnerID) == "" || len(req.OrderIDs) == 0 || req.ReceivedAmount == nil || strings.TrimSpace(req.Reference) == "" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Thiếu thông tin đối soát.", nil)
		return
	}
	seen := map[string]bool{}
	for _, oid := range req.OrderIDs {
		if seen[oid] {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Danh sách order_ids không được trùng lặp.", nil)
			return
		}
		seen[oid] = true
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		tx, err := s.db.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
			return 0, nil, false
		}
		defer tx.Rollback(r.Context())

		rows, err := tx.Query(r.Context(), `
			SELECT order_id, amount, state
			FROM fee_ledger
			WHERE owner_id = $1 AND order_id = ANY($2)
			FOR UPDATE
		`, req.OwnerID, req.OrderIDs)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi kiểm tra sổ phí.", nil)
			return 0, nil, false
		}
		perOrder := map[string]int{}
		for rows.Next() {
			var oid, st string
			var amt int
			if err := rows.Scan(&oid, &amt, &st); err != nil {
				rows.Close()
				writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi đọc sổ phí.", nil)
				return 0, nil, false
			}
			if st == "settled" {
				rows.Close()
				writeError(w, http.StatusConflict, "already_settled", "Một hoặc nhiều đơn đã được đối soát trước đó.", nil)
				return 0, nil, false
			}
			perOrder[oid] += amt
		}
		rows.Close()

		if len(perOrder) != len(req.OrderIDs) {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Danh sách đơn không hợp lệ hoặc không thuộc chủ đồ.", nil)
			return 0, nil, false
		}
		total := 0
		for _, v := range perOrder {
			total += v
		}
		if total != *req.ReceivedAmount {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Số tiền thực nhận không khớp tổng phí các đơn.", map[string]string{"received_amount": "Không khớp tổng phí"})
			return 0, nil, false
		}

		settID := newID("sett")
		now := s.now().UTC()
		if _, err := tx.Exec(r.Context(), `
			INSERT INTO settlements (id, owner_id, order_ids, received_amount, reference, confirmed_at, confirmed_by)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
		`, settID, req.OwnerID, req.OrderIDs, *req.ReceivedAmount, strings.TrimSpace(req.Reference), now, me.ID); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể lưu đối soát.", nil)
			return 0, nil, false
		}
		if _, err := tx.Exec(r.Context(), `
			UPDATE fee_ledger SET state = 'settled', settlement_id = $1
			WHERE owner_id = $2 AND order_id = ANY($3)
		`, settID, req.OwnerID, req.OrderIDs); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể cập nhật sổ phí.", nil)
			return 0, nil, false
		}
		if _, err := tx.Exec(r.Context(), `
			UPDATE orders SET fee_state = 'settled' WHERE id = ANY($1)
		`, req.OrderIDs); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể cập nhật trạng thái phí đơn.", nil)
			return 0, nil, false
		}
		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi lưu đối soát.", nil)
			return 0, nil, false
		}

		return http.StatusCreated, Settlement{
			ID:             settID,
			OwnerID:        req.OwnerID,
			OrderIDs:       req.OrderIDs,
			ReceivedAmount: *req.ReceivedAmount,
			Reference:      strings.TrimSpace(req.Reference),
			ConfirmedAt:    formatTS(now),
			ConfirmedBy:    me.ID,
		}, true
	})
}

func (s *Server) handleListSettlements(w http.ResponseWriter, r *http.Request, me Me) {
	limit := parseLimit(r)
	offset := parseOffsetCursor(r)
	rows, err := s.db.Query(r.Context(), `
		SELECT id, owner_id, order_ids, received_amount, reference, confirmed_at, confirmed_by
		FROM settlements
		WHERE owner_id = $1
		ORDER BY confirmed_at DESC, id DESC
		LIMIT $2 OFFSET $3
	`, me.ID, limit+1, offset)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tải lịch sử đối soát.", nil)
		return
	}
	defer rows.Close()

	items := make([]Settlement, 0)
	for rows.Next() {
		var st Settlement
		var ts time.Time
		if err := rows.Scan(&st.ID, &st.OwnerID, &st.OrderIDs, &st.ReceivedAmount, &st.Reference, &ts, &st.ConfirmedBy); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi đọc dữ liệu.", nil)
			return
		}
		st.ConfirmedAt = formatTS(ts)
		items = append(items, st)
	}
	var next *string
	if len(items) > limit {
		items = items[:limit]
		next = encodeOffsetCursor(offset + limit)
	}
	writeJSON(w, http.StatusOK, Page[Settlement]{Items: items, NextCursor: next})
}
