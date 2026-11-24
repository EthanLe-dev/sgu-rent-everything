package api

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

var catalogCategories = []string{
	"Điện tử & Máy ảnh",
	"Học tập & Sách",
	"Thể thao & Dã ngoại",
	"Nhạc cụ",
	"Đồ gia dụng",
	"Khác",
}

var catalogAreas = []string{
	"Cơ sở 1",
	"Cơ sở 2",
	"Cơ sở Chính",
}

func (s *Server) handleCatalogOptions(w http.ResponseWriter, r *http.Request, me Me) {
	writeJSON(w, http.StatusOK, map[string]any{
		"categories": catalogCategories,
		"areas":      catalogAreas,
	})
}

func (s *Server) handleListListings(w http.ResponseWriter, r *http.Request, me Me) {
	q := r.URL.Query()
	var args []any
	var where []string

	if search := strings.TrimSpace(q.Get("q")); search != "" {
		args = append(args, "%"+search+"%")
		idx := len(args)
		where = append(where, fmt.Sprintf("(l.title ILIKE $%d OR l.description ILIKE $%d)", idx, idx))
	}
	if cat := strings.TrimSpace(q.Get("category")); cat != "" {
		args = append(args, cat)
		where = append(where, fmt.Sprintf("l.category = $%d", len(args)))
	}
	if area := strings.TrimSpace(q.Get("area")); area != "" {
		args = append(args, area)
		where = append(where, fmt.Sprintf("l.area = $%d", len(args)))
	}
	if minRaw := strings.TrimSpace(q.Get("min_daily_rate")); minRaw != "" {
		v, err := strconv.Atoi(minRaw)
		if err != nil || v < 0 {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "min_daily_rate không hợp lệ.", nil)
			return
		}
		args = append(args, v)
		where = append(where, fmt.Sprintf("l.daily_rate >= $%d", len(args)))
	}
	if maxRaw := strings.TrimSpace(q.Get("max_daily_rate")); maxRaw != "" {
		v, err := strconv.Atoi(maxRaw)
		if err != nil || v < 0 {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "max_daily_rate không hợp lệ.", nil)
			return
		}
		args = append(args, v)
		where = append(where, fmt.Sprintf("l.daily_rate <= $%d", len(args)))
	}
	if q.Get("mine") == "true" {
		args = append(args, me.ID)
		where = append(where, fmt.Sprintf("l.owner_id = $%d", len(args)))
	}

	sd := strings.TrimSpace(q.Get("start_date"))
	ed := strings.TrimSpace(q.Get("end_date"))
	if (sd != "" && ed == "") || (sd == "" && ed != "") {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Cần truyền đủ start_date và end_date.", nil)
		return
	}
	if sd != "" && ed != "" {
		startT, err1 := parseDateStrict(sd)
		endT, err2 := parseDateStrict(ed)
		if err1 != nil || err2 != nil || endT.Before(startT) {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Khoảng ngày không hợp lệ.", nil)
			return
		}
		args = append(args, sd, ed)
		sIdx := len(args) - 1
		eIdx := len(args)
		where = append(where, fmt.Sprintf(`NOT EXISTS (
			SELECT 1 FROM listing_schedule_locks lk
			WHERE lk.listing_id = l.id AND lk.period && daterange($%d::date, ($%d::date + 1), '[)')
		)`, sIdx, eIdx))
	}

	whereSQL := ""
	if len(where) > 0 {
		whereSQL = "WHERE " + strings.Join(where, " AND ")
	}
	limit := parseLimit(r)
	offset := parseOffsetCursor(r)
	args = append(args, limit+1, offset)

	query := fmt.Sprintf(`
		SELECT l.id, u.id, u.display_name, (u.verification = 'approved'),
		       l.title, l.category, l.description, l.condition, l.accessories, l.photo_ids,
		       l.daily_rate, l.deposit, l.area, l.pickup_point, l.revision
		FROM listings l
		JOIN users u ON u.id = l.owner_id
		%s
		ORDER BY l.created_at DESC, l.id DESC
		LIMIT $%d OFFSET $%d
	`, whereSQL, len(args)-1, len(args))

	rows, err := s.db.Query(r.Context(), query, args...)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tải danh sách đồ.", nil)
		return
	}
	defer rows.Close()

	items := make([]Listing, 0)
	for rows.Next() {
		var l Listing
		if err := rows.Scan(
			&l.ID, &l.Owner.ID, &l.Owner.DisplayName, &l.Owner.Verified,
			&l.Title, &l.Category, &l.Description, &l.Condition, &l.Accessories, &l.PhotoIDs,
			&l.DailyRate, &l.Deposit, &l.Area, &l.PickupPoint, &l.Revision,
		); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi đọc dữ liệu.", nil)
			return
		}
		if l.Accessories == nil {
			l.Accessories = []string{}
		}
		if l.PhotoIDs == nil {
			l.PhotoIDs = []string{}
		}
		items = append(items, l)
	}
	var next *string
	if len(items) > limit {
		items = items[:limit]
		next = encodeOffsetCursor(offset + limit)
	}
	writeJSON(w, http.StatusOK, Page[Listing]{Items: items, NextCursor: next})
}

func (s *Server) getListingByID(ctx context.Context, id string) (Listing, error) {
	var l Listing
	err := s.db.QueryRow(ctx, `
		SELECT l.id, u.id, u.display_name, (u.verification = 'approved'),
		       l.title, l.category, l.description, l.condition, l.accessories, l.photo_ids,
		       l.daily_rate, l.deposit, l.area, l.pickup_point, l.revision
		FROM listings l
		JOIN users u ON u.id = l.owner_id
		WHERE l.id = $1
	`, id).Scan(
		&l.ID, &l.Owner.ID, &l.Owner.DisplayName, &l.Owner.Verified,
		&l.Title, &l.Category, &l.Description, &l.Condition, &l.Accessories, &l.PhotoIDs,
		&l.DailyRate, &l.Deposit, &l.Area, &l.PickupPoint, &l.Revision,
	)
	if l.Accessories == nil {
		l.Accessories = []string{}
	}
	if l.PhotoIDs == nil {
		l.PhotoIDs = []string{}
	}
	return l, err
}

func (s *Server) handleGetListing(w http.ResponseWriter, r *http.Request, me Me) {
	l, err := s.getListingByID(r.Context(), r.PathValue("id"))
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy món đồ.", nil)
		return
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tải món đồ.", nil)
		return
	}
	writeJSON(w, http.StatusOK, l)
}

type listingInput struct {
	Title       string   `json:"title"`
	Category    string   `json:"category"`
	Description string   `json:"description"`
	Condition   string   `json:"condition"`
	Accessories []string `json:"accessories"`
	PhotoIDs    []string `json:"photo_ids"`
	DailyRate   int      `json:"daily_rate"`
	Deposit     int      `json:"deposit"`
	Area        string   `json:"area"`
	PickupPoint string   `json:"pickup_point"`
}

func validateListingFields(in listingInput) map[string]string {
	fields := map[string]string{}
	if strings.TrimSpace(in.Title) == "" {
		fields["title"] = "Bắt buộc"
	}
	if !slices.Contains(catalogCategories, in.Category) {
		fields["category"] = "Danh mục không hợp lệ"
	}
	if strings.TrimSpace(in.Condition) == "" {
		fields["condition"] = "Bắt buộc"
	}
	if in.DailyRate < 0 {
		fields["daily_rate"] = "Không được âm"
	}
	if in.Deposit < 0 {
		fields["deposit"] = "Không được âm"
	}
	if !slices.Contains(catalogAreas, in.Area) {
		fields["area"] = "Khu vực giao nhận không hợp lệ"
	}
	if in.PickupPoint != in.Area {
		fields["pickup_point"] = "Phải khớp với khu vực giao nhận"
	}
	return fields
}

func (s *Server) attachListingPhotos(ctx context.Context, tx pgx.Tx, listingID, ownerID string, photoIDs []string) error {
	for _, pid := range photoIDs {
		var uploaderID, purpose string
		var existingListingID *string
		err := tx.QueryRow(ctx, `
			SELECT uploader_id, purpose, listing_id FROM photos WHERE id = $1
		`, pid).Scan(&uploaderID, &purpose, &existingListingID)
		if err != nil {
			return errors.New("invalid_photo")
		}
		if uploaderID != ownerID || purpose != "listing" || (existingListingID != nil && *existingListingID != listingID) {
			return errors.New("invalid_photo")
		}
		if _, err := tx.Exec(ctx, `UPDATE photos SET listing_id = $2 WHERE id = $1`, pid, listingID); err != nil {
			return err
		}
	}
	return nil
}

func (s *Server) handleCreateListing(w http.ResponseWriter, r *http.Request, me Me) {
	var req listingInput
	rawBody, ok := readBodyAndDecode(w, r, &req)
	if !ok {
		return
	}
	if fields := validateListingFields(req); len(fields) > 0 {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Thông tin món đồ chưa hợp lệ.", fields)
		return
	}
	if req.Accessories == nil {
		req.Accessories = []string{}
	}
	if req.PhotoIDs == nil {
		req.PhotoIDs = []string{}
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		tx, err := s.db.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
			return 0, nil, false
		}
		defer tx.Rollback(r.Context())

		id := newID("item")
		_, err = tx.Exec(r.Context(), `
			INSERT INTO listings (id, owner_id, title, category, description, condition, accessories, photo_ids, daily_rate, deposit, area, pickup_point, revision)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 1)
		`, id, me.ID, strings.TrimSpace(req.Title), req.Category, strings.TrimSpace(req.Description),
			strings.TrimSpace(req.Condition), req.Accessories, req.PhotoIDs, req.DailyRate, req.Deposit, req.Area, req.PickupPoint)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tạo tin đăng.", nil)
			return 0, nil, false
		}
		if err := s.attachListingPhotos(r.Context(), tx, id, me.ID, req.PhotoIDs); err != nil {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Ảnh đính kèm không hợp lệ.", map[string]string{"photo_ids": "Ảnh không hợp lệ hoặc không thuộc quyền sở hữu"})
			return 0, nil, false
		}
		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể lưu tin đăng.", nil)
			return 0, nil, false
		}
		l, _ := s.getListingByID(r.Context(), id)
		return http.StatusCreated, l, true
	})
}

func (s *Server) handlePatchListing(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	var patch map[string]json.RawMessage
	if _, ok := readBodyAndDecode(w, r, &patch); !ok {
		return
	}
	if len(patch) == 0 {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Cần ít nhất một trường để cập nhật.", nil)
		return
	}

	tx, err := s.db.Begin(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
		return
	}
	defer tx.Rollback(r.Context())

	var ownerID string
	var cur listingInput
	err = tx.QueryRow(r.Context(), `
		SELECT owner_id, title, category, description, condition, accessories, photo_ids, daily_rate, deposit, area, pickup_point
		FROM listings WHERE id = $1 FOR UPDATE
	`, id).Scan(&ownerID, &cur.Title, &cur.Category, &cur.Description, &cur.Condition,
		&cur.Accessories, &cur.PhotoIDs, &cur.DailyRate, &cur.Deposit, &cur.Area, &cur.PickupPoint)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy món đồ.", nil)
		return
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
		return
	}
	if ownerID != me.ID {
		writeError(w, http.StatusForbidden, "forbidden", "Chỉ chủ đồ mới được sửa tin này.", nil)
		return
	}

	patchBytes, _ := json.Marshal(patch)
	if err := json.Unmarshal(patchBytes, &cur); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Dữ liệu cập nhật không hợp lệ.", nil)
		return
	}
	if fields := validateListingFields(cur); len(fields) > 0 {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Thông tin cập nhật chưa hợp lệ.", fields)
		return
	}
	if cur.Accessories == nil {
		cur.Accessories = []string{}
	}
	if cur.PhotoIDs == nil {
		cur.PhotoIDs = []string{}
	}

	if _, err := tx.Exec(r.Context(), `
		UPDATE listings
		SET title = $2, category = $3, description = $4, condition = $5,
		    accessories = $6, photo_ids = $7, daily_rate = $8, deposit = $9,
		    area = $10, pickup_point = $11, revision = revision + 1, updated_at = $12
		WHERE id = $1
	`, id, strings.TrimSpace(cur.Title), cur.Category, strings.TrimSpace(cur.Description),
		strings.TrimSpace(cur.Condition), cur.Accessories, cur.PhotoIDs, cur.DailyRate,
		cur.Deposit, cur.Area, cur.PickupPoint, s.now().UTC()); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể cập nhật tin đăng.", nil)
		return
	}
	if err := s.attachListingPhotos(r.Context(), tx, id, me.ID, cur.PhotoIDs); err != nil {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Ảnh đính kèm không hợp lệ.", nil)
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi lưu thay đổi.", nil)
		return
	}

	updated, _ := s.getListingByID(r.Context(), id)
	writeJSON(w, http.StatusOK, updated)
}

func (s *Server) handleListingAvailability(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	if _, err := s.getListingByID(r.Context(), id); errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy món đồ.", nil)
		return
	}
	sd := r.URL.Query().Get("start_date")
	ed := r.URL.Query().Get("end_date")
	startT, err1 := parseDateStrict(sd)
	endT, err2 := parseDateStrict(ed)
	if err1 != nil || err2 != nil || endT.Before(startT) {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Khoảng ngày không hợp lệ.", nil)
		return
	}

	rows, err := s.db.Query(r.Context(), `
		SELECT start_date, end_date
		FROM listing_schedule_locks
		WHERE listing_id = $1 AND period && daterange($2::date, ($3::date + 1), '[)')
		ORDER BY start_date ASC
	`, id, sd, ed)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tải lịch.", nil)
		return
	}
	defer rows.Close()

	unavailable := make([]Range, 0)
	for rows.Next() {
		var sDate, eDate time.Time
		if err := rows.Scan(&sDate, &eDate); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi đọc lịch.", nil)
			return
		}
		unavailable = append(unavailable, Range{StartDate: formatDate(sDate), EndDate: formatDate(eDate)})
	}
	writeJSON(w, http.StatusOK, map[string]any{"unavailable": unavailable})
}

func (s *Server) handleListBlocks(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	l, err := s.getListingByID(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy món đồ.", nil)
		return
	}
	if l.Owner.ID != me.ID {
		writeError(w, http.StatusForbidden, "forbidden", "Chỉ chủ đồ mới được xem lịch bận.", nil)
		return
	}

	limit := parseLimit(r)
	offset := parseOffsetCursor(r)
	rows, err := s.db.Query(r.Context(), `
		SELECT id, start_date, end_date
		FROM listing_blocks
		WHERE listing_id = $1
		ORDER BY start_date ASC, id ASC
		LIMIT $2 OFFSET $3
	`, id, limit+1, offset)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi tải lịch bận.", nil)
		return
	}
	defer rows.Close()

	items := make([]Block, 0)
	for rows.Next() {
		var b Block
		var sDate, eDate time.Time
		if err := rows.Scan(&b.ID, &sDate, &eDate); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi đọc dữ liệu.", nil)
			return
		}
		b.StartDate = formatDate(sDate)
		b.EndDate = formatDate(eDate)
		items = append(items, b)
	}
	var next *string
	if len(items) > limit {
		items = items[:limit]
		next = encodeOffsetCursor(offset + limit)
	}
	writeJSON(w, http.StatusOK, Page[Block]{Items: items, NextCursor: next})
}

func (s *Server) handleCreateBlock(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	l, err := s.getListingByID(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy món đồ.", nil)
		return
	}
	if l.Owner.ID != me.ID {
		writeError(w, http.StatusForbidden, "forbidden", "Chỉ chủ đồ mới được khóa lịch bận.", nil)
		return
	}

	var req Range
	rawBody, ok := readBodyAndDecode(w, r, &req)
	if !ok {
		return
	}
	startT, err1 := parseDateStrict(req.StartDate)
	endT, err2 := parseDateStrict(req.EndDate)
	if err1 != nil || err2 != nil || endT.Before(startT) {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Khoảng ngày không hợp lệ.", nil)
		return
	}

	s.runIdempotent(w, r, me.ID, rawBody, func() (int, any, bool) {
		tx, err := s.db.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
			return 0, nil, false
		}
		defer tx.Rollback(r.Context())

		blockID := newID("blk")
		if _, err := tx.Exec(r.Context(), `
			INSERT INTO listing_blocks (id, listing_id, start_date, end_date)
			VALUES ($1, $2, $3::date, $4::date)
		`, blockID, id, req.StartDate, req.EndDate); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể tạo lịch bận.", nil)
			return 0, nil, false
		}
		if _, err := tx.Exec(r.Context(), `
			INSERT INTO listing_schedule_locks (id, listing_id, lock_type, block_id, start_date, end_date)
			VALUES ($1, $2, 'block', $3, $4::date, $5::date)
		`, newID("lock"), id, blockID, req.StartDate, req.EndDate); err != nil {
			if pgErrCode(err) == "23P01" {
				writeError(w, http.StatusConflict, "schedule_conflict", "Khoảng ngày này đã có lịch giữ hoặc lịch bận.", nil)
				return 0, nil, false
			}
			writeError(w, http.StatusInternalServerError, "internal_error", "Không thể khóa lịch.", nil)
			return 0, nil, false
		}
		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi lưu lịch bận.", nil)
			return 0, nil, false
		}
		return http.StatusCreated, Block{ID: blockID, StartDate: req.StartDate, EndDate: req.EndDate}, true
	})
}

func (s *Server) handleDeleteBlock(w http.ResponseWriter, r *http.Request, me Me) {
	id := r.PathValue("id")
	blockID := r.PathValue("block_id")
	l, err := s.getListingByID(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy món đồ.", nil)
		return
	}
	if l.Owner.ID != me.ID {
		writeError(w, http.StatusForbidden, "forbidden", "Chỉ chủ đồ mới được xóa lịch bận.", nil)
		return
	}

	tag, err := s.db.Exec(r.Context(), `DELETE FROM listing_blocks WHERE id = $1 AND listing_id = $2`, blockID, id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Không thể xóa lịch bận.", nil)
		return
	}
	if tag.RowsAffected() == 0 {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy lịch bận.", nil)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func computeQuote(l Listing, startStr, endStr string) (Quote, error) {
	startT, err1 := parseDateStrict(startStr)
	endT, err2 := parseDateStrict(endStr)
	if err1 != nil || err2 != nil || endT.Before(startT) {
		return Quote{}, errors.New("invalid range")
	}
	days := int(endT.Sub(startT).Hours()/24) + 1
	rent := l.DailyRate * days
	const renterFee = 1000
	const ownerFee = 1000
	return Quote{
		ListingID:       l.ID,
		ListingRevision: l.Revision,
		StartDate:       startStr,
		EndDate:         endStr,
		Days:            days,
		DailyRate:       l.DailyRate,
		Rent:            rent,
		Deposit:         l.Deposit,
		RenterFee:       renterFee,
		OwnerFee:        ownerFee,
		PickupTotal:     rent + renterFee + l.Deposit,
		OwnerNet:        rent - ownerFee,
	}, nil
}

func (s *Server) handleQuoteListing(w http.ResponseWriter, r *http.Request, me Me) {
	l, err := s.getListingByID(r.Context(), r.PathValue("id"))
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "Không tìm thấy món đồ.", nil)
		return
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Lỗi hệ thống.", nil)
		return
	}
	var req Range
	if _, ok := readBodyAndDecode(w, r, &req); !ok {
		return
	}
	q, err := computeQuote(l, req.StartDate, req.EndDate)
	if err != nil {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "Khoảng ngày không hợp lệ.", nil)
		return
	}
	writeJSON(w, http.StatusOK, q)
}
