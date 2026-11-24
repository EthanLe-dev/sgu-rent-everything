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

func (s *Server) buildOrder(ctx context.Context, qer interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
	QueryRow(context.Context, string, ...any) pgx.Row
}, orderID, viewerID string) (Order, error) {
	var o Order
	var startDate, endDate time.Time
	var createdAt time.Time
	err := qer.QueryRow(ctx, `
		SELECT o.id, o.listing_id, o.title,
		       ow.id, ow.display_name, (ow.verification = 'approved'),
		       rn.id, rn.display_name, (rn.verification = 'approved'),
		       o.listing_revision, o.start_date, o.end_date, o.days, o.daily_rate, o.rent, o.deposit,
		       o.renter_fee, o.owner_fee, o.pickup_total, o.owner_net,
		       o.accessories, o.pickup_point, o.status, o.close_reason,
		       o.deposit_status, o.deposit_refunded, o.deposit_reason, o.fee_state, o.created_at
		FROM orders o
		JOIN users ow ON ow.id = o.owner_id
		JOIN users rn ON rn.id = o.renter_id
		WHERE o.id = $1
	`, orderID).Scan(
		&o.ID, &o.ListingID, &o.Title,
		&o.Owner.ID, &o.Owner.DisplayName, &o.Owner.Verified,
		&o.Renter.ID, &o.Renter.DisplayName, &o.Renter.Verified,
		&o.Quote.ListingRevision, &startDate, &endDate, &o.Quote.Days, &o.Quote.DailyRate,
		&o.Quote.Rent, &o.Quote.Deposit, &o.Quote.RenterFee, &o.Quote.OwnerFee,
		&o.Quote.PickupTotal, &o.Quote.OwnerNet,
		&o.Accessories, &o.PickupPoint, &o.Status, &o.CloseReason,
		&o.DepositResult.Status, &o.DepositResult.Refunded, &o.DepositResult.Reason,
		&o.FeeState, &createdAt,
	)
	if err != nil {
		return Order{}, err
	}
	o.Quote.ListingID = o.ListingID
	o.Quote.StartDate = formatDate(startDate)
	o.Quote.EndDate = formatDate(endDate)
	o.CreatedAt = formatTS(createdAt)
	if o.Accessories == nil {
		o.Accessories = []string{}
	}

	today := s.todayVN()
	o.Overdue = o.Status == "active" && today.After(endDate)

	if viewerID == o.Owner.ID {
		var blockingID string
		err := qer.QueryRow(ctx, `
			SELECT order_id FROM handover_tickets
			WHERE listing_id = $1 AND closed_at IS NULL AND order_id <> $2
			LIMIT 1
		`, o.ListingID, o.ID).Scan(&blockingID)
		if err == nil {
			o.BlockingOrderID = &blockingID
		}
	}

	o.Pickup = []Receipt{}
	o.Returned = []Receipt{}
	rows, err := qer.Query(ctx, `
		SELECT kind, actor_id, confirmed_at, condition, accessories, photo_ids, cash_received
		FROM order_confirmations
		WHERE order_id = $1
		ORDER BY confirmed_at ASC
	`, orderID)
	if err != nil {
		return Order{}, err
	}
	for rows.Next() {
		var kind string
		var rec Receipt
		var confAt time.Time
		if err := rows.Scan(&kind, &rec.ActorID, &confAt, &rec.Condition, &rec.Accessories, &rec.PhotoIDs, &rec.CashReceived); err != nil {
			rows.Close()
			return Order{}, err
		}
		rec.ConfirmedAt = formatTS(confAt)
		if rec.Accessories == nil {
			rec.Accessories = []string{}
		}
		if rec.PhotoIDs == nil {
			rec.PhotoIDs = []string{}
		}
		if kind == "pickup" {
			o.Pickup = append(o.Pickup, rec)
		} else {
			o.Returned = append(o.Returned, rec)
		}
	}
	rows.Close()

	o.DepositResult.Claims = []Claim{}
	cRows, err := qer.Query(ctx, `
		SELECT actor_id, refunded, reason, confirmed_at
		FROM deposit_claims
		WHERE order_id = $1
		ORDER BY confirmed_at ASC
	`, orderID)
	if err != nil {
		return Order{}, err
	}
	for cRows.Next() {
		var cl Claim
		var confAt time.Time
		if err := cRows.Scan(&cl.ActorID, &cl.Refunded, &cl.Reason, &confAt); err != nil {
			cRows.Close()
			return Order{}, err
		}
		cl.ConfirmedAt = formatTS(confAt)
		o.DepositResult.Claims = append(o.DepositResult.Claims, cl)
	}
	cRows.Close()

	var hasHandoverCase bool
	_ = qer.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM cases WHERE target_type='order' AND target_id=$1 AND category='handover' AND status='open')
	`, orderID).Scan(&hasHandoverCase)

	o.AllowedActions = computeAllowedActions(o, viewerID, hasHandoverCase)
	return o, nil
}

func computeAllowedActions(o Order, viewerID string, hasHandoverCase bool) []string {
	if viewerID != o.Owner.ID && viewerID != o.Renter.ID {
		return []string{}
	}
	hasActor := func(list []Receipt) bool {
		for _, r := range list {
			if r.ActorID == viewerID {
				return true
			}
		}
		return false
	}
	hasClaim := func(list []Claim) bool {
		for _, c := range list {
			if c.ActorID == viewerID {
				return true
			}
		}
		return false
	}

	switch o.Status {
	case "requested":
		if viewerID == o.Owner.ID {
			return []string{"approve", "reject", "cancel", "message", "report"}
		}
		return []string{"cancel", "message", "report"}
	case "approved":
		actions := []string{}
		if len(o.Pickup) == 0 {
			actions = append(actions, "cancel")
		}
		if !hasHandoverCase && !hasActor(o.Pickup) {
			actions = append(actions, "pickup")
		}
		actions = append(actions, "message", "report")
		return actions
	case "active":
		actions := []string{}
		if !hasActor(o.Returned) {
			actions = append(actions, "return")
		}
		actions = append(actions, "message", "report")
		return actions
	case "returned":
		actions := []string{}
		if !hasClaim(o.DepositResult.Claims) {
			actions = append(actions, "deposit")
		}
		actions = append(actions, "message", "report")
		return actions
	default:
		return []string{"message", "report"}
	}
}

func (s *Server) canViewOrder(ctx context.Context, orderID string, me Me) (ownerID, renterID string, ok bool) {
	err := s.db.QueryRow(ctx, `SELECT owner_id, renter_id FROM orders WHERE id = $1`, orderID).Scan(&ownerID, &renterID)
	if err != nil {
		return "", "", false
	}
	if me.ID == ownerID || me.ID == renterID {
		return ownerID, renterID, true
	}
	if me.Role == "admin" {
		var hasCase bool
		_ = s.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM cases WHERE target_type='order' AND target_id=$1)`, orderID).Scan(&hasCase)
		if hasCase {
			return ownerID, renterID, true
		}
	}
	return "", "", false
}

func (s *Server) insertOutbox(ctx context.Context, tx pgx.Tx, eventType, targetType, targetID string, recipients []string) error {
	if len(recipients) == 0 {
		return nil
	}
	_, err := tx.Exec(ctx, `
		INSERT INTO outbox_events (id, event_type, occurred_at, target_type, target_id, recipient_ids)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, newID("evt"), eventType, s.now().UTC(), targetType, targetID, recipients)
	return err
}

func (s *Server) handleCreateOrder(w http.ResponseWriter, r *http.Request, me Me) {
	var req struct {
		ListingID       string  `json:"listing_id"`
		ListingRevision int     `json:"listing_revision"`
		StartDate       string  `json:"start_date"`
		EndDate         string  `json:"end_date"`
		Note            *string `json:"note"`
	}
	rawBody, ok := readBodyAndDecode(w, r, &req)
	if !ok {
		return
	}

	l, err := s.getListingByID(r.Context(), req.ListingID)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy món đồ.", nil)
		return
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
		return
	}
	if l.Owner.ID == me.ID {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Không thể thuê đồ của chính mình.", nil)
		return
	}
	q, err := computeQuote(l, req.StartDate, req.EndDate)
	if err != nil {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Khoảng ngày không hợp lệ.", nil)
		return
	}
	endT, _ := parseDateStrict(req.EndDate)
	if endT.Before(s.todayVN()) {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Ngày kết thúc đã qua.", nil)
		return
	}
	if req.ListingRevision != l.Revision {
		writeError(w, http.StatusConflict, "quote_changed", "Thông tin món đồ đã thay đổi, vui lòng xem lại báo giá mới.", nil)
		return
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		tx, err := s.db.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
			return 0, nil, false
		}
		defer tx.Rollback(r.Context())

		orderID := newID("order")
		now := s.now().UTC()
		_, err = tx.Exec(r.Context(), `
			INSERT INTO orders (
				id, listing_id, owner_id, renter_id, title, listing_revision,
				start_date, end_date, days, daily_rate, rent, deposit,
				renter_fee, owner_fee, pickup_total, owner_net,
				accessories, pickup_point, status, deposit_status, fee_state, created_at
			) VALUES (
				$1, $2, $3, $4, $5, $6,
				$7::date, $8::date, $9, $10, $11, $12,
				$13, $14, $15, $16,
				$17, $18, 'requested', 'pending', 'unaccrued', $19
			)
		`, orderID, l.ID, l.Owner.ID, me.ID, l.Title, l.Revision,
			req.StartDate, req.EndDate, q.Days, q.DailyRate, q.Rent, q.Deposit,
			q.RenterFee, q.OwnerFee, q.PickupTotal, q.OwnerNet,
			l.Accessories, l.PickupPoint, now)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tạo yêu cầu thuê.", nil)
			return 0, nil, false
		}

		if req.Note != nil && strings.TrimSpace(*req.Note) != "" {
			if _, err := tx.Exec(r.Context(), `
				INSERT INTO order_messages (id, order_id, sender_id, text, created_at)
				VALUES ($1, $2, $3, $4, $5)
			`, newID("msg"), orderID, me.ID, strings.TrimSpace(*req.Note), now); err != nil {
				writeError(w, http.StatusInternalServerError, "internal_error", "Không thể lưu ghi chú.", nil)
				return 0, nil, false
			}
		}

		if err := s.insertOutbox(r.Context(), tx, "order_requested", "order", orderID, []string{l.Owner.ID}); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tạo thông báo.", nil)
			return 0, nil, false
		}

		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi lưu yêu cầu.", nil)
			return 0, nil, false
		}
		o, err := s.buildOrder(r.Context(), s.db, orderID, me.ID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tải đơn.", nil)
			return 0, nil, false
		}
		return http.StatusCreated, o, true
	})
}

func (s *Server) handleListOrders(w http.ResponseWriter, r *http.Request, me Me) {
	as := r.URL.Query().Get("as")
	if as != "owner" && as != "renter" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Tham số as phải là owner hoặc renter.", nil)
		return
	}
	col := "owner_id"
	if as == "renter" {
		col = "renter_id"
	}

	args := []any{me.ID}
	where := []string{fmt.Sprintf("%s = $1", col)}
	if st := strings.TrimSpace(r.URL.Query().Get("status")); st != "" {
		args = append(args, st)
		where = append(where, fmt.Sprintf("status = $%d", len(args)))
	}

	limit := parseLimit(r)
	offset := parseOffsetCursor(r)
	args = append(args, limit+1, offset)

	query := fmt.Sprintf(`
		SELECT id FROM orders
		WHERE %s
		ORDER BY created_at DESC, id DESC
		LIMIT $%d OFFSET $%d
	`, strings.Join(where, " AND "), len(args)-1, len(args))

	rows, err := s.db.Query(r.Context(), query, args...)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tải danh sách đơn.", nil)
		return
	}
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi đọc dữ liệu.", nil)
			return
		}
		ids = append(ids, id)
	}
	rows.Close()

	var next *string
	if len(ids) > limit {
		ids = ids[:limit]
		next = encodeOffsetCursor(offset + limit)
	}

	items := make([]Order, 0, len(ids))
	for _, id := range ids {
		o, err := s.buildOrder(r.Context(), s.db, id, me.ID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tải chi tiết đơn.", nil)
			return
		}
		items = append(items, o)
	}
	writeJSON(w, http.StatusOK, Page[Order]{Items: items, NextCursor: next})
}

func (s *Server) handleGetOrder(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	if _, _, ok := s.canViewOrder(r.Context(), id, me); !ok {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
		return
	}
	o, err := s.buildOrder(r.Context(), s.db, id, me.ID)
	if err != nil {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
		return
	}
	writeJSON(w, http.StatusOK, o)
}

func (s *Server) handleApproveOrder(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	rawBody, ok := readBodyAndDecode(w, r, &struct{}{})
	if !ok {
		return
	}
	ownerID, _, viewOK := s.canViewOrder(r.Context(), id, me)
	if !viewOK {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
		return
	}
	if ownerID != me.ID {
		writeError(w, http.StatusForbidden, "forbidden", "Chỉ chủ đồ mới được duyệt đơn.", nil)
		return
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		tx, err := s.db.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
			return 0, nil, false
		}
		defer tx.Rollback(r.Context())

		var listingID, renterID, status string
		var startDate, endDate time.Time
		err = tx.QueryRow(r.Context(), `
			SELECT listing_id, renter_id, status, start_date, end_date
			FROM orders WHERE id = $1 FOR UPDATE
		`, id).Scan(&listingID, &renterID, &status, &startDate, &endDate)
		if err != nil {
			writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
			return 0, nil, false
		}
		if status != "requested" {
			writeError(w, http.StatusConflict, "invalid_state", "Đơn không ở trạng thái chờ duyệt.", nil)
			return 0, nil, false
		}
		if endDate.Before(s.todayVN()) {
			_, _ = tx.Exec(r.Context(), `UPDATE orders SET status = 'expired', close_reason = 'expired' WHERE id = $1`, id)
			_ = tx.Commit(r.Context())
			writeError(w, http.StatusConflict, "invalid_state", "Yêu cầu đã hết hạn.", nil)
			return 0, nil, false
		}

		if _, err := tx.Exec(r.Context(), `
			INSERT INTO listing_schedule_locks (id, listing_id, lock_type, order_id, start_date, end_date)
			VALUES ($1, $2, 'order', $3, $4, $5)
		`, newID("lock"), listingID, id, startDate, endDate); err != nil {
			if pgErrCode(err) == "23P01" {
				writeError(w, http.StatusConflict, "schedule_conflict", "Món này đã có lịch trong khoảng ngày bạn chọn.", nil)
				return 0, nil, false
			}
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể giữ lịch.", nil)
			return 0, nil, false
		}

		if _, err := tx.Exec(r.Context(), `UPDATE orders SET status = 'approved' WHERE id = $1`, id); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể duyệt đơn.", nil)
			return 0, nil, false
		}

		// Close overlapping requested orders atomically
		cRows, err := tx.Query(r.Context(), `
			UPDATE orders
			SET status = 'rejected', close_reason = 'schedule_conflict'
			WHERE listing_id = $1 AND id <> $2 AND status = 'requested'
			  AND daterange(start_date, end_date + 1, '[)') && daterange($3::date, ($4::date + 1), '[)')
			RETURNING id, renter_id
		`, listingID, id, startDate, endDate)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể đóng đơn trùng lịch.", nil)
			return 0, nil, false
		}
		type closedOrder struct{ id, renterID string }
		var closed []closedOrder
		for cRows.Next() {
			var c closedOrder
			if err := cRows.Scan(&c.id, &c.renterID); err == nil {
				closed = append(closed, c)
			}
		}
		cRows.Close()

		if err := s.insertOutbox(r.Context(), tx, "order_approved", "order", id, []string{renterID}); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tạo thông báo.", nil)
			return 0, nil, false
		}
		for _, c := range closed {
			if err := s.insertOutbox(r.Context(), tx, "order_closed", "order", c.id, []string{c.renterID}); err != nil {
				writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tạo thông báo.", nil)
				return 0, nil, false
			}
		}

		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi lưu duyệt đơn.", nil)
			return 0, nil, false
		}
		o, _ := s.buildOrder(r.Context(), s.db, id, me.ID)
		return http.StatusOK, o, true
	})
}

func (s *Server) handleRejectOrder(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	var req struct {
		Reason string `json:"reason"`
	}
	rawBody, ok := readBodyAndDecode(w, r, &req)
	if !ok {
		return
	}
	if strings.TrimSpace(req.Reason) == "" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Cần nhập lý do từ chối.", map[string]string{"reason": "Bắt buộc"})
		return
	}
	ownerID, _, viewOK := s.canViewOrder(r.Context(), id, me)
	if !viewOK {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
		return
	}
	if ownerID != me.ID {
		writeError(w, http.StatusForbidden, "forbidden", "Chỉ chủ đồ mới được từ chối đơn.", nil)
		return
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		tx, err := s.db.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
			return 0, nil, false
		}
		defer tx.Rollback(r.Context())

		var renterID, status string
		err = tx.QueryRow(r.Context(), `SELECT renter_id, status FROM orders WHERE id = $1 FOR UPDATE`, id).Scan(&renterID, &status)
		if err != nil || status != "requested" {
			writeError(w, http.StatusConflict, "invalid_state", "Đơn không ở trạng thái chờ duyệt.", nil)
			return 0, nil, false
		}
		if _, err := tx.Exec(r.Context(), `UPDATE orders SET status = 'rejected', close_reason = $2 WHERE id = $1`, id, strings.TrimSpace(req.Reason)); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể từ chối đơn.", nil)
			return 0, nil, false
		}
		if err := s.insertOutbox(r.Context(), tx, "order_closed", "order", id, []string{renterID}); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tạo thông báo.", nil)
			return 0, nil, false
		}
		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi lưu.", nil)
			return 0, nil, false
		}
		o, _ := s.buildOrder(r.Context(), s.db, id, me.ID)
		return http.StatusOK, o, true
	})
}

func (s *Server) handleCancelOrder(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	var req struct {
		Reason string `json:"reason"`
	}
	rawBody, ok := readBodyAndDecode(w, r, &req)
	if !ok {
		return
	}
	if strings.TrimSpace(req.Reason) == "" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Cần nhập lý do hủy.", map[string]string{"reason": "Bắt buộc"})
		return
	}
	ownerID, renterID, viewOK := s.canViewOrder(r.Context(), id, me)
	if !viewOK || (me.ID != ownerID && me.ID != renterID) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
		return
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		tx, err := s.db.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
			return 0, nil, false
		}
		defer tx.Rollback(r.Context())

		var status string
		if err := tx.QueryRow(r.Context(), `SELECT status FROM orders WHERE id = $1 FOR UPDATE`, id).Scan(&status); err != nil {
			writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
			return 0, nil, false
		}
		if status != "requested" && status != "approved" {
			writeError(w, http.StatusConflict, "invalid_state", "Không thể hủy đơn ở trạng thái hiện tại.", nil)
			return 0, nil, false
		}
		if status == "approved" {
			var pickupCount int
			_ = tx.QueryRow(r.Context(), `SELECT COUNT(*) FROM order_confirmations WHERE order_id = $1 AND kind = 'pickup'`, id).Scan(&pickupCount)
			if pickupCount > 0 {
				writeError(w, http.StatusConflict, "pickup_started", "Đã có xác nhận giao đồ, không thể hủy đơn.", nil)
				return 0, nil, false
			}
		}

		if _, err := tx.Exec(r.Context(), `UPDATE orders SET status = 'cancelled', close_reason = $2 WHERE id = $1`, id, strings.TrimSpace(req.Reason)); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể hủy đơn.", nil)
			return 0, nil, false
		}
		_, _ = tx.Exec(r.Context(), `DELETE FROM listing_schedule_locks WHERE order_id = $1`, id)

		other := ownerID
		if me.ID == ownerID {
			other = renterID
		}
		if err := s.insertOutbox(r.Context(), tx, "order_closed", "order", id, []string{other}); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tạo thông báo.", nil)
			return 0, nil, false
		}
		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi lưu.", nil)
			return 0, nil, false
		}
		o, _ := s.buildOrder(r.Context(), s.db, id, me.ID)
		return http.StatusOK, o, true
	})
}

func (s *Server) validateHandoverPhotos(ctx context.Context, tx pgx.Tx, orderID, uploaderID string, photoIDs []string) bool {
	for _, pid := range photoIDs {
		var uID, purpose string
		var oID *string
		err := tx.QueryRow(ctx, `SELECT uploader_id, purpose, order_id FROM photos WHERE id = $1`, pid).Scan(&uID, &purpose, &oID)
		if err != nil || uID != uploaderID || purpose != "handover" || oID == nil || *oID != orderID {
			return false
		}
	}
	return true
}

func (s *Server) handlePickupOrder(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	var req struct {
		Condition    string   `json:"condition"`
		Accessories  []string `json:"accessories"`
		PhotoIDs     []string `json:"photo_ids"`
		CashReceived *int     `json:"cash_received"`
	}
	rawBody, ok := readBodyAndDecode(w, r, &req)
	if !ok {
		return
	}
	if req.Accessories == nil {
		req.Accessories = []string{}
	}
	if req.PhotoIDs == nil {
		req.PhotoIDs = []string{}
	}
	if strings.TrimSpace(req.Condition) == "" || req.CashReceived == nil {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Thiếu tình trạng hoặc số tiền thực trao.", nil)
		return
	}

	ownerID, renterID, viewOK := s.canViewOrder(r.Context(), id, me)
	if !viewOK || (me.ID != ownerID && me.ID != renterID) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
		return
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		tx, err := s.db.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
			return 0, nil, false
		}
		defer tx.Rollback(r.Context())

		var listingID, status string
		var pickupTotal, renterFee, ownerFee int
		var endDate time.Time
		err = tx.QueryRow(r.Context(), `
			SELECT listing_id, status, pickup_total, renter_fee, owner_fee, end_date
			FROM orders WHERE id = $1 FOR UPDATE
		`, id).Scan(&listingID, &status, &pickupTotal, &renterFee, &ownerFee, &endDate)
		if err != nil {
			writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
			return 0, nil, false
		}

		// Check if same actor already confirmed pickup (idempotent retry even with new Idempotency-Key)
		var prevCond string
		var prevAcc, prevPhotos []string
		var prevCash *int
		err = tx.QueryRow(r.Context(), `
			SELECT condition, accessories, photo_ids, cash_received
			FROM order_confirmations
			WHERE order_id = $1 AND kind = 'pickup' AND actor_id = $2
		`, id, me.ID).Scan(&prevCond, &prevAcc, &prevPhotos, &prevCash)
		if err == nil {
			if prevCond == req.Condition && slices.Equal(prevAcc, req.Accessories) &&
				slices.Equal(prevPhotos, req.PhotoIDs) && prevCash != nil && *prevCash == *req.CashReceived {
				o, _ := s.buildOrder(r.Context(), tx, id, me.ID)
				_ = tx.Commit(r.Context())
				return http.StatusOK, o, true
			}
			writeError(w, http.StatusConflict, "confirmation_conflict", "Bạn đã xác nhận giao đồ với nội dung khác.", nil)
			return 0, nil, false
		}

		if status != "approved" {
			writeError(w, http.StatusConflict, "invalid_state", "Đơn không ở trạng thái chờ giao đồ.", nil)
			return 0, nil, false
		}
		var hasHandoverCase bool
		_ = tx.QueryRow(r.Context(), `
			SELECT EXISTS(SELECT 1 FROM cases WHERE target_type='order' AND target_id=$1 AND category='handover' AND status='open')
		`, id).Scan(&hasHandoverCase)
		if hasHandoverCase {
			writeError(w, http.StatusConflict, "handover_disputed", "Đơn đang có vụ việc bàn giao chờ xử lý.", nil)
			return 0, nil, false
		}
		if endDate.Before(s.todayVN()) {
			writeError(w, http.StatusConflict, "invalid_state", "Đã quá ngày kết thúc thuê.", nil)
			return 0, nil, false
		}
		if *req.CashReceived != pickupTotal {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Số tiền thực trao phải khớp tổng tiền nhận đồ.", map[string]string{"cash_received": "Không khớp tổng tiền báo giá"})
			return 0, nil, false
		}
		if !s.validateHandoverPhotos(r.Context(), tx, id, me.ID, req.PhotoIDs) {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Ảnh bàn giao không hợp lệ.", map[string]string{"photo_ids": "Ảnh không thuộc đơn hoặc người gửi"})
			return 0, nil, false
		}

		now := s.now().UTC()
		if _, err := tx.Exec(r.Context(), `
			INSERT INTO order_confirmations (id, order_id, kind, actor_id, condition, accessories, photo_ids, cash_received, confirmed_at)
			VALUES ($1, $2, 'pickup', $3, $4, $5, $6, $7, $8)
		`, newID("conf"), id, me.ID, req.Condition, req.Accessories, req.PhotoIDs, *req.CashReceived, now); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể ghi nhận xác nhận giao.", nil)
			return 0, nil, false
		}

		var count int
		_ = tx.QueryRow(r.Context(), `SELECT COUNT(*) FROM order_confirmations WHERE order_id = $1 AND kind = 'pickup'`, id).Scan(&count)
		if count >= 2 {
			// Both confirmed: open handover ticket, set active, accrue fees in ONE transaction
			if _, err := tx.Exec(r.Context(), `
				INSERT INTO handover_tickets (id, order_id, listing_id, holder_id, opened_at)
				VALUES ($1, $2, $3, $4, $5)
			`, newID("hnd"), id, listingID, renterID, now); err != nil {
				if pgErrCode(err) == "23505" {
					writeError(w, http.StatusConflict, "item_not_returned", "Món đồ này đang được giữ ở một đơn khác chưa trả.", nil)
					return 0, nil, false
				}
				writeError(w, http.StatusInternalServerError, "internal_error", "Không thể mở phiếu bàn giao.", nil)
				return 0, nil, false
			}
			if _, err := tx.Exec(r.Context(), `UPDATE orders SET status = 'active', fee_state = 'outstanding' WHERE id = $1`, id); err != nil {
				writeError(w, http.StatusInternalServerError, "internal_error", "Không thể chuyển trạng thái đơn.", nil)
				return 0, nil, false
			}
			if _, err := tx.Exec(r.Context(), `
				INSERT INTO fee_ledger (id, order_id, owner_id, payer_role, amount, state, accrued_at)
				VALUES ($1, $3, $4, 'renter', $5, 'outstanding', $7),
				       ($2, $3, $4, 'owner', $6, 'outstanding', $7)
				ON CONFLICT (order_id, payer_role) DO NOTHING
			`, newID("fee"), newID("fee"), id, ownerID, renterFee, ownerFee, now); err != nil {
				writeError(w, http.StatusInternalServerError, "internal_error", "Không thể ghi sổ phí.", nil)
				return 0, nil, false
			}
			_ = s.insertOutbox(r.Context(), tx, "pickup_confirmed", "order", id, []string{ownerID, renterID})
		} else {
			other := ownerID
			if me.ID == ownerID {
				other = renterID
			}
			_ = s.insertOutbox(r.Context(), tx, "pickup_confirmed", "order", id, []string{other})
		}

		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi lưu xác nhận giao.", nil)
			return 0, nil, false
		}
		o, _ := s.buildOrder(r.Context(), s.db, id, me.ID)
		return http.StatusOK, o, true
	})
}

func (s *Server) handleReturnOrder(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	var req struct {
		Condition   string   `json:"condition"`
		Accessories []string `json:"accessories"`
		PhotoIDs    []string `json:"photo_ids"`
	}
	rawBody, ok := readBodyAndDecode(w, r, &req)
	if !ok {
		return
	}
	if req.Accessories == nil {
		req.Accessories = []string{}
	}
	if req.PhotoIDs == nil {
		req.PhotoIDs = []string{}
	}
	if strings.TrimSpace(req.Condition) == "" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Cần ghi nhận tình trạng khi trả.", nil)
		return
	}

	ownerID, renterID, viewOK := s.canViewOrder(r.Context(), id, me)
	if !viewOK || (me.ID != ownerID && me.ID != renterID) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
		return
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		tx, err := s.db.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
			return 0, nil, false
		}
		defer tx.Rollback(r.Context())

		var status string
		var deposit int
		err = tx.QueryRow(r.Context(), `SELECT status, deposit FROM orders WHERE id = $1 FOR UPDATE`, id).Scan(&status, &deposit)
		if err != nil {
			writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
			return 0, nil, false
		}

		var prevCond string
		var prevAcc, prevPhotos []string
		err = tx.QueryRow(r.Context(), `
			SELECT condition, accessories, photo_ids
			FROM order_confirmations
			WHERE order_id = $1 AND kind = 'return' AND actor_id = $2
		`, id, me.ID).Scan(&prevCond, &prevAcc, &prevPhotos)
		if err == nil {
			if prevCond == req.Condition && slices.Equal(prevAcc, req.Accessories) && slices.Equal(prevPhotos, req.PhotoIDs) {
				o, _ := s.buildOrder(r.Context(), tx, id, me.ID)
				_ = tx.Commit(r.Context())
				return http.StatusOK, o, true
			}
			writeError(w, http.StatusConflict, "confirmation_conflict", "Bạn đã xác nhận trả đồ với nội dung khác.", nil)
			return 0, nil, false
		}

		if status != "active" {
			writeError(w, http.StatusConflict, "invalid_state", "Đơn không ở trạng thái đang thuê.", nil)
			return 0, nil, false
		}
		if !s.validateHandoverPhotos(r.Context(), tx, id, me.ID, req.PhotoIDs) {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Ảnh trả đồ không hợp lệ.", nil)
			return 0, nil, false
		}

		now := s.now().UTC()
		if _, err := tx.Exec(r.Context(), `
			INSERT INTO order_confirmations (id, order_id, kind, actor_id, condition, accessories, photo_ids, confirmed_at)
			VALUES ($1, $2, 'return', $3, $4, $5, $6, $7)
		`, newID("conf"), id, me.ID, req.Condition, req.Accessories, req.PhotoIDs, now); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể ghi nhận xác nhận trả.", nil)
			return 0, nil, false
		}

		var count int
		_ = tx.QueryRow(r.Context(), `SELECT COUNT(*) FROM order_confirmations WHERE order_id = $1 AND kind = 'return'`, id).Scan(&count)
		if count >= 2 {
			_, _ = tx.Exec(r.Context(), `UPDATE handover_tickets SET closed_at = $2 WHERE order_id = $1 AND closed_at IS NULL`, id, now)
			_, _ = tx.Exec(r.Context(), `DELETE FROM listing_schedule_locks WHERE order_id = $1`, id)

			if deposit == 0 {
				_, _ = tx.Exec(r.Context(), `
					UPDATE orders SET status = 'completed', deposit_status = 'agreed', deposit_refunded = 0 WHERE id = $1
				`, id)
			} else {
				_, _ = tx.Exec(r.Context(), `UPDATE orders SET status = 'returned' WHERE id = $1`, id)
			}
			_ = s.insertOutbox(r.Context(), tx, "return_confirmed", "order", id, []string{ownerID, renterID})
		} else {
			other := ownerID
			if me.ID == ownerID {
				other = renterID
			}
			_ = s.insertOutbox(r.Context(), tx, "return_confirmed", "order", id, []string{other})
		}

		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi lưu xác nhận trả.", nil)
			return 0, nil, false
		}
		o, _ := s.buildOrder(r.Context(), s.db, id, me.ID)
		return http.StatusOK, o, true
	})
}

func (s *Server) handleDepositOrder(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	var req struct {
		Refunded *int    `json:"refunded"`
		Reason   *string `json:"reason"`
	}
	rawBody, ok := readBodyAndDecode(w, r, &req)
	if !ok {
		return
	}
	if req.Refunded == nil {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Cần nhập số tiền hoàn cọc.", nil)
		return
	}

	ownerID, renterID, viewOK := s.canViewOrder(r.Context(), id, me)
	if !viewOK || (me.ID != ownerID && me.ID != renterID) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
		return
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		tx, err := s.db.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
			return 0, nil, false
		}
		defer tx.Rollback(r.Context())

		var status string
		var deposit int
		err = tx.QueryRow(r.Context(), `SELECT status, deposit FROM orders WHERE id = $1 FOR UPDATE`, id).Scan(&status, &deposit)
		if err != nil {
			writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
			return 0, nil, false
		}

		var prevRefunded int
		var prevReason *string
		err = tx.QueryRow(r.Context(), `SELECT refunded, reason FROM deposit_claims WHERE order_id = $1 AND actor_id = $2`, id, me.ID).Scan(&prevRefunded, &prevReason)
		if err == nil {
			sameReason := (prevReason == nil && req.Reason == nil) || (prevReason != nil && req.Reason != nil && *prevReason == *req.Reason)
			if prevRefunded == *req.Refunded && sameReason {
				o, _ := s.buildOrder(r.Context(), tx, id, me.ID)
				_ = tx.Commit(r.Context())
				return http.StatusOK, o, true
			}
			writeError(w, http.StatusConflict, "confirmation_conflict", "Bạn đã xác nhận kết quả cọc khác trước đó.", nil)
			return 0, nil, false
		}

		if status != "returned" {
			writeError(w, http.StatusConflict, "invalid_state", "Đơn chưa ở trạng thái chờ hoàn cọc.", nil)
			return 0, nil, false
		}
		if *req.Refunded < 0 || *req.Refunded > deposit {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Số tiền hoàn cọc không hợp lệ.", map[string]string{"refunded": "Phải từ 0 đến tiền cọc"})
			return 0, nil, false
		}
		if *req.Refunded < deposit && (req.Reason == nil || strings.TrimSpace(*req.Reason) == "") {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Cần nêu lý do khi khấu trừ cọc.", map[string]string{"reason": "Bắt buộc khi khấu trừ"})
			return 0, nil, false
		}

		now := s.now().UTC()
		if _, err := tx.Exec(r.Context(), `
			INSERT INTO deposit_claims (id, order_id, actor_id, refunded, reason, confirmed_at)
			VALUES ($1, $2, $3, $4, $5, $6)
		`, newID("dep"), id, me.ID, *req.Refunded, req.Reason, now); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể lưu kết quả cọc.", nil)
			return 0, nil, false
		}

		rows, err := tx.Query(r.Context(), `SELECT refunded, reason FROM deposit_claims WHERE order_id = $1 ORDER BY confirmed_at ASC`, id)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi đọc xác nhận cọc.", nil)
			return 0, nil, false
		}
		type dc struct {
			refunded int
			reason   *string
		}
		var claims []dc
		for rows.Next() {
			var c dc
			if err := rows.Scan(&c.refunded, &c.reason); err == nil {
				claims = append(claims, c)
			}
		}
		rows.Close()

		if len(claims) >= 2 {
			if claims[0].refunded == claims[1].refunded {
				var finalReason *string
				for _, c := range claims {
					if c.reason != nil && strings.TrimSpace(*c.reason) != "" {
						finalReason = c.reason
						break
					}
				}
				_, _ = tx.Exec(r.Context(), `
					UPDATE orders SET status = 'completed', deposit_status = 'agreed', deposit_refunded = $2, deposit_reason = $3 WHERE id = $1
				`, id, claims[0].refunded, finalReason)
			} else {
				_, _ = tx.Exec(r.Context(), `UPDATE orders SET deposit_status = 'disputed' WHERE id = $1`, id)
				var exists bool
				_ = tx.QueryRow(r.Context(), `
					SELECT EXISTS(SELECT 1 FROM cases WHERE target_type='order' AND target_id=$1 AND category='deposit' AND status='open')
				`, id).Scan(&exists)
				if !exists {
					caseID := newID("case")
					_, _ = tx.Exec(r.Context(), `
						INSERT INTO cases (id, target_type, target_id, reporter_id, category, detail, status, created_at)
						VALUES ($1, 'order', $2, $3, 'deposit', 'Bất đồng kết quả hoàn cọc giữa hai bên.', 'open', $4)
					`, caseID, id, me.ID, now)
					_ = s.insertOutbox(r.Context(), tx, "case_opened", "case", caseID, []string{ownerID, renterID})
				}
			}
		}

		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi lưu kết quả cọc.", nil)
			return 0, nil, false
		}
		o, _ := s.buildOrder(r.Context(), s.db, id, me.ID)
		return http.StatusOK, o, true
	})
}

func (s *Server) handleListMessages(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	if _, _, ok := s.canViewOrder(r.Context(), id, me); !ok {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
		return
	}
	limit := parseLimit(r)
	offset := parseOffsetCursor(r)
	rows, err := s.db.Query(r.Context(), `
		SELECT id, order_id, sender_id, text, created_at
		FROM order_messages
		WHERE order_id = $1
		ORDER BY created_at ASC, id ASC
		LIMIT $2 OFFSET $3
	`, id, limit+1, offset)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tải tin nhắn.", nil)
		return
	}
	defer rows.Close()

	items := make([]Message, 0)
	for rows.Next() {
		var m Message
		var ts time.Time
		if err := rows.Scan(&m.ID, &m.OrderID, &m.SenderID, &m.Text, &ts); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi đọc tin nhắn.", nil)
			return
		}
		m.CreatedAt = formatTS(ts)
		items = append(items, m)
	}
	var next *string
	if len(items) > limit {
		items = items[:limit]
		next = encodeOffsetCursor(offset + limit)
	}
	writeJSON(w, http.StatusOK, Page[Message]{Items: items, NextCursor: next})
}

func (s *Server) handleCreateMessage(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	var req struct {
		Text string `json:"text"`
	}
	rawBody, ok := readBodyAndDecode(w, r, &req)
	if !ok {
		return
	}
	if strings.TrimSpace(req.Text) == "" {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Tin nhắn không được để trống.", nil)
		return
	}
	ownerID, renterID, viewOK := s.canViewOrder(r.Context(), id, me)
	if !viewOK || (me.ID != ownerID && me.ID != renterID) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy đơn thuê.", nil)
		return
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		msgID := newID("msg")
		now := s.now().UTC()
		_, err := s.db.Exec(r.Context(), `
			INSERT INTO order_messages (id, order_id, sender_id, text, created_at)
			VALUES ($1, $2, $3, $4, $5)
		`, msgID, id, me.ID, strings.TrimSpace(req.Text), now)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể gửi tin nhắn.", nil)
			return 0, nil, false
		}
		return http.StatusCreated, Message{
			ID:        msgID,
			OrderID:   id,
			SenderID:  me.ID,
			Text:      strings.TrimSpace(req.Text),
			CreatedAt: formatTS(now),
		}, true
	})
}
