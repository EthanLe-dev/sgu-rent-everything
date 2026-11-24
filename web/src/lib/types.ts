export type UserRole = 'student' | 'admin';
export type VerificationStatus = 'unsubmitted' | 'pending' | 'approved' | 'rejected';

export interface User {
  id: string;
  display_name: string;
  verified: boolean;
}

export interface Me extends User {
  email: string;
  role: UserRole;
  verification: VerificationStatus;
  full_name: string | null;
  student_code: string | null;
  class_name: string | null;
  faculty: string | null;
  review_note: string | null;
}

export interface Page<T> {
  items: T[];
  next_cursor: string | null;
}

export interface DateRange {
  start_date: string;
  end_date: string;
}

export interface Block extends DateRange {
  id: string;
}

export interface ListingInput {
  title: string;
  category: string;
  description: string;
  condition: string;
  accessories: string[];
  photo_ids: string[];
  daily_rate: number;
  deposit: number;
  area: string;
  pickup_point: string;
}

export interface Listing extends ListingInput {
  id: string;
  owner: User;
  revision: number;
}

export interface Quote {
  listing_id: string;
  listing_revision: number;
  start_date: string;
  end_date: string;
  days: number;
  daily_rate: number;
  rent: number;
  deposit: number;
  renter_fee: number;
  owner_fee: number;
  pickup_total: number;
  owner_net: number;
}

export interface Receipt {
  actor_id: string;
  confirmed_at: string;
  condition: string;
  accessories: string[];
  photo_ids: string[];
  cash_received: number | null;
}

export interface Claim {
  actor_id: string;
  refunded: number;
  reason: string | null;
  confirmed_at: string;
}

export interface DepositResult {
  status: 'pending' | 'disputed' | 'agreed' | 'resolved';
  refunded: number | null;
  reason: string | null;
  claims: Claim[];
}

export type OrderStatus =
  | 'requested'
  | 'approved'
  | 'active'
  | 'returned'
  | 'completed'
  | 'cancelled'
  | 'rejected'
  | 'expired';

export type FeeState = 'unaccrued' | 'outstanding' | 'settled';

export interface Order {
  id: string;
  listing_id: string;
  title: string;
  owner: User;
  renter: User;
  quote: Quote;
  accessories: string[];
  pickup_point: string;
  status: OrderStatus;
  close_reason: string | null;
  overdue: boolean;
  blocking_order_id: string | null;
  pickup: Receipt[];
  returned: Receipt[];
  deposit_result: DepositResult;
  fee_state: FeeState;
  allowed_actions: string[];
  created_at: string;
}

export interface Message {
  id: string;
  order_id: string;
  sender_id: string;
  text: string;
  created_at: string;
}

export interface Case {
  id: string;
  target_type: 'listing' | 'order';
  target_id: string;
  reporter_id: string;
  category: string;
  detail: string;
  status: 'open' | 'resolved';
  resolution: string | null;
  created_at: string;
}

export interface FeeSummary {
  accrued: number;
  settled: number;
  outstanding: number;
}

export interface FeeEntry {
  order_id: string;
  accrued_at: string;
  renter_fee: number;
  owner_fee: number;
  total: number;
  state: 'outstanding' | 'settled';
  settlement_id: string | null;
}

export interface OwnerFees {
  owner: User;
  summary: FeeSummary;
}

export interface Settlement {
  id: string;
  owner_id: string;
  order_ids: string[];
  received_amount: number;
  reference: string;
  confirmed_at: string;
  confirmed_by: string;
}

export interface Notice {
  id: string;
  type: string;
  title: string;
  body: string;
  target_type: 'order' | 'case';
  target_id: string;
  read_at: string | null;
  created_at: string;
}
