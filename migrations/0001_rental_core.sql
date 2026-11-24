CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'admin')),
    verification TEXT NOT NULL DEFAULT 'unsubmitted' CHECK (verification IN ('unsubmitted', 'pending', 'approved', 'rejected')),
    full_name TEXT,
    student_code TEXT,
    class_name TEXT,
    faculty TEXT,
    review_note TEXT,
    reviewed_by TEXT REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_users_approved_student_code
    ON users (student_code)
    WHERE verification = 'approved' AND student_code IS NOT NULL;

CREATE TABLE otp_challenges (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL,
    code_hash TEXT NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_otp_challenges_email_created ON otp_challenges (email, created_at DESC);

CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE listings (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL REFERENCES users(id),
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT NOT NULL,
    condition TEXT NOT NULL,
    accessories TEXT[] NOT NULL DEFAULT '{}',
    photo_ids TEXT[] NOT NULL DEFAULT '{}',
    daily_rate INT NOT NULL CHECK (daily_rate >= 0),
    deposit INT NOT NULL CHECK (deposit >= 0),
    area TEXT NOT NULL,
    pickup_point TEXT NOT NULL,
    revision INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_listings_owner ON listings (owner_id);
CREATE INDEX idx_listings_area_category ON listings (area, category);

CREATE TABLE listing_blocks (
    id TEXT PRIMARY KEY,
    listing_id TEXT NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (end_date >= start_date)
);

CREATE TABLE orders (
    id TEXT PRIMARY KEY,
    listing_id TEXT NOT NULL REFERENCES listings(id),
    owner_id TEXT NOT NULL REFERENCES users(id),
    renter_id TEXT NOT NULL REFERENCES users(id),
    title TEXT NOT NULL,
    listing_revision INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    days INT NOT NULL CHECK (days >= 1),
    daily_rate INT NOT NULL CHECK (daily_rate >= 0),
    rent INT NOT NULL CHECK (rent >= 0),
    deposit INT NOT NULL CHECK (deposit >= 0),
    renter_fee INT NOT NULL DEFAULT 1000,
    owner_fee INT NOT NULL DEFAULT 1000,
    pickup_total INT NOT NULL,
    owner_net INT NOT NULL,
    accessories TEXT[] NOT NULL DEFAULT '{}',
    pickup_point TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('requested', 'approved', 'active', 'returned', 'completed', 'cancelled', 'rejected', 'expired')),
    close_reason TEXT,
    deposit_status TEXT NOT NULL DEFAULT 'pending' CHECK (deposit_status IN ('pending', 'disputed', 'agreed', 'resolved')),
    deposit_refunded INT,
    deposit_reason TEXT,
    fee_state TEXT NOT NULL DEFAULT 'unaccrued' CHECK (fee_state IN ('unaccrued', 'outstanding', 'settled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (end_date >= start_date),
    CHECK (owner_id <> renter_id)
);

CREATE INDEX idx_orders_owner ON orders (owner_id, created_at DESC);
CREATE INDEX idx_orders_renter ON orders (renter_id, created_at DESC);
CREATE INDEX idx_orders_listing_status ON orders (listing_id, status);

CREATE TABLE listing_schedule_locks (
    id TEXT PRIMARY KEY,
    listing_id TEXT NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    lock_type TEXT NOT NULL CHECK (lock_type IN ('order', 'block')),
    order_id TEXT UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    block_id TEXT UNIQUE REFERENCES listing_blocks(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    period DATERANGE GENERATED ALWAYS AS (daterange(start_date, end_date + 1, '[)')) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (end_date >= start_date),
    EXCLUDE USING gist (listing_id WITH =, period WITH &&)
);

CREATE TABLE photos (
    id TEXT PRIMARY KEY,
    uploader_id TEXT NOT NULL REFERENCES users(id),
    purpose TEXT NOT NULL CHECK (purpose IN ('listing', 'handover')),
    order_id TEXT REFERENCES orders(id),
    listing_id TEXT REFERENCES listings(id),
    s3_key TEXT NOT NULL,
    content_type TEXT NOT NULL,
    size_bytes INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE order_confirmations (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('pickup', 'return')),
    actor_id TEXT NOT NULL REFERENCES users(id),
    condition TEXT NOT NULL,
    accessories TEXT[] NOT NULL DEFAULT '{}',
    photo_ids TEXT[] NOT NULL DEFAULT '{}',
    cash_received INT,
    confirmed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (order_id, kind, actor_id)
);

CREATE TABLE handover_tickets (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL UNIQUE REFERENCES orders(id),
    listing_id TEXT NOT NULL REFERENCES listings(id),
    holder_id TEXT NOT NULL REFERENCES users(id),
    opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_handover_tickets_open_listing
    ON handover_tickets (listing_id)
    WHERE closed_at IS NULL;

CREATE TABLE deposit_claims (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    actor_id TEXT NOT NULL REFERENCES users(id),
    refunded INT NOT NULL CHECK (refunded >= 0),
    reason TEXT,
    confirmed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (order_id, actor_id)
);

CREATE TABLE order_messages (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL REFERENCES users(id),
    text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_order_messages_order ON order_messages (order_id, created_at ASC, id ASC);

CREATE TABLE cases (
    id TEXT PRIMARY KEY,
    target_type TEXT NOT NULL CHECK (target_type IN ('listing', 'order')),
    target_id TEXT NOT NULL,
    reporter_id TEXT NOT NULL REFERENCES users(id),
    category TEXT NOT NULL CHECK (category IN ('listing_content', 'description', 'accessory', 'damage', 'overdue', 'deposit', 'handover', 'other')),
    detail TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved')),
    resolution TEXT,
    resolved_by TEXT REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_cases_open_handover
    ON cases (target_id)
    WHERE target_type = 'order' AND category = 'handover' AND status = 'open';

CREATE TABLE settlements (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL REFERENCES users(id),
    order_ids TEXT[] NOT NULL,
    received_amount INT NOT NULL CHECK (received_amount >= 0),
    reference TEXT NOT NULL,
    confirmed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    confirmed_by TEXT NOT NULL REFERENCES users(id)
);

CREATE TABLE fee_ledger (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES orders(id),
    owner_id TEXT NOT NULL REFERENCES users(id),
    payer_role TEXT NOT NULL CHECK (payer_role IN ('renter', 'owner')),
    amount INT NOT NULL CHECK (amount >= 0),
    state TEXT NOT NULL DEFAULT 'outstanding' CHECK (state IN ('outstanding', 'settled')),
    settlement_id TEXT REFERENCES settlements(id),
    accrued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (order_id, payer_role)
);

CREATE INDEX idx_fee_ledger_owner ON fee_ledger (owner_id, state);

CREATE TABLE idempotency_keys (
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    method TEXT NOT NULL,
    path TEXT NOT NULL,
    idem_key TEXT NOT NULL,
    request_hash TEXT NOT NULL,
    status_code INT NOT NULL,
    response_body BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, method, path, idem_key)
);

CREATE TABLE outbox_events (
    id TEXT PRIMARY KEY,
    event_type TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    target_type TEXT NOT NULL,
    target_id TEXT NOT NULL,
    recipient_ids TEXT[] NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    delivered_at TIMESTAMPTZ,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_outbox_pending ON outbox_events (next_attempt_at) WHERE delivered_at IS NULL;
