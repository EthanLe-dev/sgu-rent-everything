package api

import "time"

type ErrorBody struct {
	Error ErrorDetail `json:"error"`
}

type ErrorDetail struct {
	Code    string            `json:"code"`
	Message string            `json:"message"`
	Fields  map[string]string `json:"fields"`
}

type Page[T any] struct {
	Items      []T     `json:"items"`
	NextCursor *string `json:"next_cursor"`
}

type User struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
	Verified    bool   `json:"verified"`
}

type Me struct {
	ID           string  `json:"id"`
	DisplayName  string  `json:"display_name"`
	Verified     bool    `json:"verified"`
	Email        string  `json:"email"`
	Role         string  `json:"role"`
	Verification string  `json:"verification"`
	FullName     *string `json:"full_name"`
	StudentCode  *string `json:"student_code"`
	ClassName    *string `json:"class_name"`
	Faculty      *string `json:"faculty"`
	ReviewNote   *string `json:"review_note"`
}

type Listing struct {
	ID          string   `json:"id"`
	Owner       User     `json:"owner"`
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
	Revision    int      `json:"revision"`
}

type Range struct {
	StartDate string `json:"start_date"`
	EndDate   string `json:"end_date"`
}

type Block struct {
	ID        string `json:"id"`
	StartDate string `json:"start_date"`
	EndDate   string `json:"end_date"`
}

type Quote struct {
	ListingID       string `json:"listing_id"`
	ListingRevision int    `json:"listing_revision"`
	StartDate       string `json:"start_date"`
	EndDate         string `json:"end_date"`
	Days            int    `json:"days"`
	DailyRate       int    `json:"daily_rate"`
	Rent            int    `json:"rent"`
	Deposit         int    `json:"deposit"`
	RenterFee       int    `json:"renter_fee"`
	OwnerFee        int    `json:"owner_fee"`
	PickupTotal     int    `json:"pickup_total"`
	OwnerNet        int    `json:"owner_net"`
}

type Receipt struct {
	ActorID      string   `json:"actor_id"`
	ConfirmedAt  string   `json:"confirmed_at"`
	Condition    string   `json:"condition"`
	Accessories  []string `json:"accessories"`
	PhotoIDs     []string `json:"photo_ids"`
	CashReceived *int     `json:"cash_received"`
}

type Claim struct {
	ActorID     string  `json:"actor_id"`
	Refunded    int     `json:"refunded"`
	Reason      *string `json:"reason"`
	ConfirmedAt string  `json:"confirmed_at"`
}

type DepositResult struct {
	Status   string  `json:"status"`
	Refunded *int    `json:"refunded"`
	Reason   *string `json:"reason"`
	Claims   []Claim `json:"claims"`
}

type Order struct {
	ID              string        `json:"id"`
	ListingID       string        `json:"listing_id"`
	Title           string        `json:"title"`
	Owner           User          `json:"owner"`
	Renter          User          `json:"renter"`
	Quote           Quote         `json:"quote"`
	Accessories     []string      `json:"accessories"`
	PickupPoint     string        `json:"pickup_point"`
	Status          string        `json:"status"`
	CloseReason     *string       `json:"close_reason"`
	Overdue         bool          `json:"overdue"`
	BlockingOrderID *string       `json:"blocking_order_id"`
	Pickup          []Receipt     `json:"pickup"`
	Returned        []Receipt     `json:"returned"`
	DepositResult   DepositResult `json:"deposit_result"`
	FeeState        string        `json:"fee_state"`
	AllowedActions  []string      `json:"allowed_actions"`
	CreatedAt       string        `json:"created_at"`
}

type Message struct {
	ID        string `json:"id"`
	OrderID   string `json:"order_id"`
	SenderID  string `json:"sender_id"`
	Text      string `json:"text"`
	CreatedAt string `json:"created_at"`
}

type Case struct {
	ID         string  `json:"id"`
	TargetType string  `json:"target_type"`
	TargetID   string  `json:"target_id"`
	ReporterID string  `json:"reporter_id"`
	Category   string  `json:"category"`
	Detail     string  `json:"detail"`
	Status     string  `json:"status"`
	Resolution *string `json:"resolution"`
	CreatedAt  string  `json:"created_at"`
}

type FeeSummary struct {
	Accrued     int `json:"accrued"`
	Settled     int `json:"settled"`
	Outstanding int `json:"outstanding"`
}

type FeeEntry struct {
	OrderID      string  `json:"order_id"`
	AccruedAt    string  `json:"accrued_at"`
	RenterFee    int     `json:"renter_fee"`
	OwnerFee     int     `json:"owner_fee"`
	Total        int     `json:"total"`
	State        string  `json:"state"`
	SettlementID *string `json:"settlement_id"`
}

type OwnerFees struct {
	Owner   User       `json:"owner"`
	Summary FeeSummary `json:"summary"`
}

type Settlement struct {
	ID             string   `json:"id"`
	OwnerID        string   `json:"owner_id"`
	OrderIDs       []string `json:"order_ids"`
	ReceivedAmount int      `json:"received_amount"`
	Reference      string   `json:"reference"`
	ConfirmedAt    string   `json:"confirmed_at"`
	ConfirmedBy    string   `json:"confirmed_by"`
}

func formatTS(t time.Time) string {
	return t.UTC().Format(time.RFC3339)
}

func formatDate(t time.Time) string {
	return t.Format("2006-01-02")
}
