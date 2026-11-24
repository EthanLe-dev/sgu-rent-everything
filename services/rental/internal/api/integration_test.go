package api_test

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"sgu-rent-everything/services/rental/internal/api"
)

func setupTestServer(t *testing.T) (*api.Server, *pgxpool.Pool, http.Handler) {
	t.Helper()
	dbURL := os.Getenv("TEST_DATABASE_URL")
	if dbURL == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping real PostgreSQL integration test")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		t.Fatalf("pgxpool.New: %v", err)
	}
	t.Cleanup(pool.Close)

	// Clean transactional data between tests while preserving schema
	_, err = pool.Exec(ctx, `
		TRUNCATE TABLE
			outbox_events, idempotency_keys, fee_ledger, settlements,
			cases, order_messages, deposit_claims, handover_tickets,
			order_confirmations, listing_schedule_locks, listing_blocks,
			photos, orders, listings, sessions, otp_challenges, users
		CASCADE
	`)
	if err != nil {
		t.Fatalf("truncate: %v", err)
	}

	// Seed test users and 1 listing
	_, err = pool.Exec(ctx, `
		INSERT INTO users (id, email, display_name, role, verification, full_name, student_code) VALUES
		('u-owner', 'owner@sgu.test', 'Chủ đồ', 'student', 'approved', 'Owner', '31210001'),
		('u-renter1', 'r1@sgu.test', 'Thuê 1', 'student', 'approved', 'Renter 1', '31210002'),
		('u-renter2', 'r2@sgu.test', 'Thuê 2', 'student', 'approved', 'Renter 2', '31210003'),
		('u-pending', 'pend@sgu.test', 'Chờ duyệt', 'student', 'pending', 'Pending', '31210004'),
		('u-admin', 'admin@sgu.test', 'Admin', 'admin', 'approved', 'Admin', 'ADMIN1');

		INSERT INTO listings (id, owner_id, title, category, description, condition, accessories, photo_ids, daily_rate, deposit, area, pickup_point, revision)
		VALUES ('item-1', 'u-owner', 'Máy ảnh', 'Điện tử & Máy ảnh', 'Tốt', 'Như mới', ARRAY['Pin'], '{}', 50000, 300000, 'Cơ sở Chính', 'Cơ sở Chính', 1);
	`)
	if err != nil {
		t.Fatalf("seed users/listing: %v", err)
	}

	for _, uid := range []string{"u-owner", "u-renter1", "u-renter2", "u-pending", "u-admin"} {
		sum := sha256.Sum256([]byte("tok-" + uid))
		_, err = pool.Exec(ctx, `
			INSERT INTO sessions (id, user_id, token_hash, expires_at)
			VALUES ($1, $2, $3, now() + interval '365 days')
		`, "sess-"+uid, uid, hex.EncodeToString(sum[:]))
		if err != nil {
			t.Fatalf("seed session: %v", err)
		}
	}

	srv := api.NewServer(pool, api.Config{
		OTPPepper:          "test-pepper",
		OTPCooldownSeconds: 0,
	})
	srv.SetClock(func() time.Time {
		return time.Date(2027, 3, 5, 10, 0, 0, 0, time.UTC)
	})
	return srv, pool, srv.Routes()
}

func doReq(t *testing.T, h http.Handler, method, path, token, idemKey string, body any) (int, []byte) {
	t.Helper()
	var r io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			t.Fatal(err)
		}
		r = bytes.NewReader(b)
	}
	req := httptest.NewRequest(method, path, r)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if idemKey != "" {
		req.Header.Set("Idempotency-Key", idemKey)
	}
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec.Code, rec.Body.Bytes()
}

func mustID(t *testing.T, raw []byte) string {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil {
		t.Fatalf("unmarshal: %v (%s)", err, string(raw))
	}
	id, _ := m["id"].(string)
	if id == "" {
		t.Fatalf("missing id in %s", string(raw))
	}
	return id
}

func TestConcurrentApproveScheduleConflict(t *testing.T) {
	_, _, h := setupTestServer(t)

	// Renter 1: 2027-03-05..2027-03-06
	code, b1 := doReq(t, h, "POST", "/v1/orders", "tok-u-renter1", "k-o1", map[string]any{
		"listing_id": "item-1", "listing_revision": 1, "start_date": "2027-03-05", "end_date": "2027-03-06",
	})
	if code != 201 {
		t.Fatalf("create order1: %d %s", code, b1)
	}
	o1 := mustID(t, b1)

	// Renter 2: 2027-03-06..2027-03-07 (shares boundary day 2027-03-06 -> conflict!)
	code, b2 := doReq(t, h, "POST", "/v1/orders", "tok-u-renter2", "k-o2", map[string]any{
		"listing_id": "item-1", "listing_revision": 1, "start_date": "2027-03-06", "end_date": "2027-03-07",
	})
	if code != 201 {
		t.Fatalf("create order2: %d %s", code, b2)
	}
	o2 := mustID(t, b2)

	// Renter 2 also requests next-day non-overlapping: 2027-03-07..2027-03-08
	code, b3 := doReq(t, h, "POST", "/v1/orders", "tok-u-renter2", "k-o3", map[string]any{
		"listing_id": "item-1", "listing_revision": 1, "start_date": "2027-03-07", "end_date": "2027-03-08",
	})
	if code != 201 {
		t.Fatalf("create order3: %d %s", code, b3)
	}
	o3 := mustID(t, b3)

	// Concurrently approve o1 and o2
	var wg sync.WaitGroup
	codes := make([]int, 2)
	wg.Add(2)
	go func() {
		defer wg.Done()
		codes[0], _ = doReq(t, h, "POST", "/v1/orders/"+o1+"/approve", "tok-u-owner", "k-app1", map[string]any{})
	}()
	go func() {
		defer wg.Done()
		codes[1], _ = doReq(t, h, "POST", "/v1/orders/"+o2+"/approve", "tok-u-owner", "k-app2", map[string]any{})
	}()
	wg.Wait()

	okCount, conflictCount := 0, 0
	for _, c := range codes {
		if c == 200 {
			okCount++
		} else if c == 409 {
			conflictCount++
		}
	}
	if okCount != 1 || conflictCount != 1 {
		t.Fatalf("expected 1x200 and 1x409, got %v", codes)
	}

	// Non-overlapping order3 on 2027-03-07..2027-03-08 must succeed if o1 won
	code, _ = doReq(t, h, "POST", "/v1/orders/"+o3+"/approve", "tok-u-owner", "k-app3", map[string]any{})
	if codes[0] == 200 && code != 200 {
		t.Fatalf("expected next-day order3 approve=200, got %d", code)
	}
}

func TestPickupRetryAndHandoverDispute(t *testing.T) {
	_, _, h := setupTestServer(t)

	code, b := doReq(t, h, "POST", "/v1/orders", "tok-u-renter1", "k-o1", map[string]any{
		"listing_id": "item-1", "listing_revision": 1, "start_date": "2027-03-05", "end_date": "2027-03-06",
	})
	if code != 201 {
		t.Fatalf("create: %d %s", code, b)
	}
	oid := mustID(t, b)
	code, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/approve", "tok-u-owner", "k-app", map[string]any{})
	if code != 200 {
		t.Fatalf("approve: %d", code)
	}

	pickupBody := map[string]any{
		"condition": "Tốt", "accessories": []string{"Pin"}, "photo_ids": []string{}, "cash_received": 401000,
	}
	// Owner confirms pickup
	code, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/pickup", "tok-u-owner", "k-p1", pickupBody)
	if code != 200 {
		t.Fatalf("owner pickup: %d", code)
	}
	// Retry with DIFFERENT Idempotency-Key & same payload -> 200, still 1 receipt
	code, bRetry := doReq(t, h, "POST", "/v1/orders/"+oid+"/pickup", "tok-u-owner", "k-p1-retry", pickupBody)
	if code != 200 {
		t.Fatalf("owner pickup retry: %d %s", code, bRetry)
	}
	var ord api.Order
	_ = json.Unmarshal(bRetry, &ord)
	if len(ord.Pickup) != 1 || ord.Status != "approved" || ord.FeeState != "unaccrued" {
		t.Fatalf("unexpected state after 1 pickup: %+v", ord)
	}

	// Retry with DIFFERENT payload -> 409 confirmation_conflict
	code, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/pickup", "tok-u-owner", "k-p1-diff", map[string]any{
		"condition": "Trầy nhẹ", "accessories": []string{"Pin"}, "photo_ids": []string{}, "cash_received": 401000,
	})
	if code != 409 {
		t.Fatalf("expected 409 confirmation_conflict, got %d", code)
	}

	// Renter tries cancel after 1st pickup -> 409 pickup_started
	code, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/cancel", "tok-u-renter1", "k-can", map[string]any{"reason": "Đổi ý"})
	if code != 409 {
		t.Fatalf("expected 409 pickup_started, got %d", code)
	}

	// Renter opens handover case
	code, bCase := doReq(t, h, "POST", "/v1/cases", "tok-u-renter1", "k-case", map[string]any{
		"target_type": "order", "target_id": oid, "category": "handover", "detail": "Chưa nhận được máy",
	})
	if code != 201 {
		t.Fatalf("create handover case: %d %s", code, bCase)
	}
	caseID := mustID(t, bCase)

	// Renter tries pickup while handover case open -> 409 handover_disputed
	code, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/pickup", "tok-u-renter1", "k-p2-blocked", pickupBody)
	if code != 409 {
		t.Fatalf("expected 409 handover_disputed, got %d", code)
	}

	// Admin resolves handover case with resume
	code, _ = doReq(t, h, "POST", "/v1/admin/cases/"+caseID+"/resolve", "tok-u-admin", "k-res", map[string]any{
		"resolution": "Hai bên đã gặp lại", "handover_outcome": "resume",
	})
	if code != 200 {
		t.Fatalf("resolve handover case: %d", code)
	}

	// Renter now confirms pickup -> active & outstanding
	code, bAct := doReq(t, h, "POST", "/v1/orders/"+oid+"/pickup", "tok-u-renter1", "k-p2", pickupBody)
	if code != 200 {
		t.Fatalf("renter pickup: %d %s", code, bAct)
	}
	_ = json.Unmarshal(bAct, &ord)
	if ord.Status != "active" || ord.FeeState != "outstanding" || len(ord.Pickup) != 2 {
		t.Fatalf("expected active & outstanding, got %+v", ord)
	}
}

func TestReturnDepositDisputeAndAccessControl(t *testing.T) {
	_, _, h := setupTestServer(t)

	// Pending user cannot create listing -> 403
	code, _ := doReq(t, h, "POST", "/v1/listings", "tok-u-pending", "k-pend", map[string]any{
		"title": "Test", "category": "Khác", "description": "x", "condition": "Tốt",
		"accessories": []string{}, "photo_ids": []string{}, "daily_rate": 10000, "deposit": 0,
		"area": "Cơ sở 1", "pickup_point": "Cơ sở 1",
	})
	if code != 403 {
		t.Fatalf("expected 403 for pending user, got %d", code)
	}

	// Create, approve, pickup order
	_, b := doReq(t, h, "POST", "/v1/orders", "tok-u-renter1", "k-o1", map[string]any{
		"listing_id": "item-1", "listing_revision": 1, "start_date": "2027-03-05", "end_date": "2027-03-06",
	})
	oid := mustID(t, b)
	_, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/approve", "tok-u-owner", "k-app", map[string]any{})
	pb := map[string]any{"condition": "Tốt", "accessories": []string{"Pin"}, "photo_ids": []string{}, "cash_received": 401000}
	_, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/pickup", "tok-u-owner", "k-p1", pb)
	_, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/pickup", "tok-u-renter1", "k-p2", pb)

	// Third-party user (u-renter2) cannot view order -> 404
	code, _ = doReq(t, h, "GET", "/v1/orders/"+oid, "tok-u-renter2", "", nil)
	if code != 404 {
		t.Fatalf("expected 404 for third party order read, got %d", code)
	}

	// Both return
	rb := map[string]any{"condition": "Tốt", "accessories": []string{"Pin"}, "photo_ids": []string{}}
	_, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/return", "tok-u-owner", "k-r1", rb)
	code, bRet := doReq(t, h, "POST", "/v1/orders/"+oid+"/return", "tok-u-renter1", "k-r2", rb)
	if code != 200 {
		t.Fatalf("return: %d", code)
	}
	var ord api.Order
	_ = json.Unmarshal(bRet, &ord)
	if ord.Status != "returned" {
		t.Fatalf("expected returned, got %s", ord.Status)
	}

	// Disagree on deposit
	_, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/deposit", "tok-u-owner", "k-d1", map[string]any{"refunded": 250000, "reason": "Trầy nhẹ"})
	code, bDep := doReq(t, h, "POST", "/v1/orders/"+oid+"/deposit", "tok-u-renter1", "k-d2", map[string]any{"refunded": 300000})
	if code != 200 {
		t.Fatalf("deposit: %d %s", code, bDep)
	}
	_ = json.Unmarshal(bDep, &ord)
	if ord.DepositResult.Status != "disputed" {
		t.Fatalf("expected disputed, got %s", ord.DepositResult.Status)
	}

	// Admin resolves deposit case
	code, bCases := doReq(t, h, "GET", "/v1/admin/cases?status=open", "tok-u-admin", "", nil)
	if code != 200 {
		t.Fatalf("admin cases: %d", code)
	}
	var cPage api.Page[api.Case]
	_ = json.Unmarshal(bCases, &cPage)
	if len(cPage.Items) != 1 {
		t.Fatalf("expected 1 open deposit case, got %d", len(cPage.Items))
	}
	code, _ = doReq(t, h, "POST", "/v1/admin/cases/"+cPage.Items[0].ID+"/resolve", "tok-u-admin", "k-cres", map[string]any{
		"resolution": "Hoàn 280.000đ", "refunded": 280000,
	})
	if code != 200 {
		t.Fatalf("resolve deposit case: %d", code)
	}
	_, bFinal := doReq(t, h, "GET", "/v1/orders/"+oid, "tok-u-renter1", "", nil)
	_ = json.Unmarshal(bFinal, &ord)
	if ord.Status != "completed" || ord.DepositResult.Status != "resolved" || *ord.DepositResult.Refunded != 280000 {
		t.Fatalf("expected completed+resolved+280000, got %+v", ord)
	}
}

func TestSettlementReplayAndDuplicatePrevention(t *testing.T) {
	_, _, h := setupTestServer(t)

	var orderIDs []string
	for i := range 5 {
		sd := fmt.Sprintf("2027-03-%02d", 10+i)
		_, b := doReq(t, h, "POST", "/v1/orders", "tok-u-renter1", fmt.Sprintf("k-o-%d", i), map[string]any{
			"listing_id": "item-1", "listing_revision": 1, "start_date": sd, "end_date": sd,
		})
		oid := mustID(t, b)
		_, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/approve", "tok-u-owner", fmt.Sprintf("k-a-%d", i), map[string]any{})
		pb := map[string]any{"condition": "Tốt", "accessories": []string{"Pin"}, "photo_ids": []string{}, "cash_received": 351000}
		_, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/pickup", "tok-u-owner", fmt.Sprintf("k-po-%d", i), pb)
		_, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/pickup", "tok-u-renter1", fmt.Sprintf("k-pr-%d", i), pb)
		rb := map[string]any{"condition": "Tốt", "accessories": []string{"Pin"}, "photo_ids": []string{}}
		_, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/return", "tok-u-owner", fmt.Sprintf("k-ro-%d", i), rb)
		_, _ = doReq(t, h, "POST", "/v1/orders/"+oid+"/return", "tok-u-renter1", fmt.Sprintf("k-rr-%d", i), rb)
		orderIDs = append(orderIDs, oid)
	}

	// Check owner summary = 10.000đ outstanding
	_, bSum := doReq(t, h, "GET", "/v1/fees/summary", "tok-u-owner", "", nil)
	var fs api.FeeSummary
	_ = json.Unmarshal(bSum, &fs)
	if fs.Accrued != 10000 || fs.Outstanding != 10000 {
		t.Fatalf("expected 10000 outstanding, got %+v", fs)
	}

	// Settle 5 orders
	settBody := map[string]any{
		"owner_id": "u-owner", "order_ids": orderIDs, "received_amount": 10000, "reference": "CK-001",
	}
	code, bSett1 := doReq(t, h, "POST", "/v1/admin/settlements", "tok-u-admin", "k-sett-1", settBody)
	if code != 201 {
		t.Fatalf("settlement: %d %s", code, bSett1)
	}
	// Replay same Idempotency-Key -> 201 same Settlement
	code, bSett2 := doReq(t, h, "POST", "/v1/admin/settlements", "tok-u-admin", "k-sett-1", settBody)
	if code != 201 || string(bSett1) != string(bSett2) {
		t.Fatalf("settlement replay mismatch: %d %s vs %s", code, bSett1, bSett2)
	}
	// New Idempotency-Key -> 409 already_settled
	code, _ = doReq(t, h, "POST", "/v1/admin/settlements", "tok-u-admin", "k-sett-2", settBody)
	if code != 409 {
		t.Fatalf("expected 409 already_settled, got %d", code)
	}
}
