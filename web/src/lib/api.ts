import { calculateRentalDays } from './format';
import type {
  Block,
  Case,
  DateRange,
  FeeEntry,
  FeeSummary,
  Listing,
  ListingInput,
  Me,
  Message,
  Notice,
  Order,
  OwnerFees,
  Page,
  Quote,
  Settlement,
} from './types';

export class ApiClientError extends Error {
  status: number;
  code: string;
  fields: Record<string, string>;
  retryAfter?: number;

  constructor(
    status: number,
    code: string,
    message: string,
    fields: Record<string, string> = {},
    retryAfter?: number,
  ) {
    super(message);
    this.status = status;
    this.code = code;
    this.fields = fields;
    this.retryAfter = retryAfter;
  }
}

export const STITCH_FALLBACK_PHOTOS: Record<string, string> = {
  'item-1':
    'https://lh3.googleusercontent.com/aida/ALJJyrC4C1Mxx31lDTbbqSLUSWt6P0x0TcDvCxo3Zm3r18kXv-o-moR6_kL9gOUPMgJJ1VmHReOPCWo9Ymvk0TXdg28XSHEFcuFbkZIq290P1KotPoSqOJNSk7EJfeT7aOTx8SHtxQlrQZ1RFdDqdzVHw2npOPZrfS5e0-6Zhs7P43BZk1F6okQbqJeir_eDY-8e8rxpsf5Tm6Z9WTS1csCOZ4IWgIix-wVbYguVb0RySiAqP_85alyGLdMlrw',
  'item-2':
    'https://lh3.googleusercontent.com/aida/ALJJyrAQD0f8ZQYToPm8M2M75wFClr6IUYaMKgIfFL6upbKC4BldVObVOxcy8J5Bp7XLKmb1DGiMcxDiJBbXyNIj0TLnUpjwlieutdBNLmO-ntj3SsOQ4vAoWvyVOetc_4S1MhlhKU-fpujDT7n8DoIhS5MxhMpyFwgxLhl4Tt27Vmo3v7r8pi6nUrHrYdm4ekICLIT5hyJ_0RSekTz5HUOTvNaJ4oSdHY1STJDj_x9KVaSFr78mMRvwhqIuBEN4f5Qx',
  'item-3':
    'https://lh3.googleusercontent.com/aida/ALJJyrBT6mHW65LnRHvCectV5gxFtTfyQqT9FtAOdAgqR-XiAin_Z3XY4VayxGV3Kb93z8cHn3rmZqS1wlzxq7NW8bIsObvFCQEAy2IPKV1nONSFuOd-fV_9l30g6VWLYXs0zisp9Qqj5mSQvMy3hmHwSMBli23-rdzbWWUMw5cMnXfwQaQl_MT2BSVejg6KIxS0muiu2ZKe2nIi6KRR0p0CKeBWJKET5R3l388h5XKvk6Js9Ul-9NFp',
  default:
    'https://lh3.googleusercontent.com/aida/ALJJyrDlLaL0SqCoJ-U04vq-6A4u0vT603KevY_TVQ7v0NPXBZXFw_9lkj8nl41-VD_aBGBq2-HWtX9J7w6dtdPTIQo3yMP7KJFCRDQM9NgWoIgkQBYYlVXEizxh_XsKL6cfGrAktstq42TR9ABLVGEJt9g0SYzlmcwr8TuAkeLMLC71vJaXde57bYcUrqrn6wc0R_yQfpuOHZWVU1gCNlW4UirP50Y7ssEQrzrwWAweOPa2i-3P1k4',
};

const STORAGE_TOKEN_KEY = 'sgu_rent_web_token';
const STORAGE_MODE_KEY = 'sgu_rent_web_use_mock';

export function newIdempotencyKey(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'idem-' + Math.random().toString(36).slice(2) + '-' + Date.now();
}

class RentWebClient {
  private token: string | null = null;
  private mockMode = false;

  // In-memory mock store for instant demo/testing when mockMode is enabled
  private mockMe: Me = {
    id: 'user-renter',
    display_name: 'Minh',
    verified: true,
    email: 'nguoithue@sgu.test',
    role: 'student',
    verification: 'approved',
    full_name: 'Trần Thị Thuê',
    student_code: '3121410002',
    class_name: 'DCT1212',
    faculty: 'Công nghệ Thông tin',
    review_note: null,
  };

  private mockUsers: Record<string, Me> = {
    'chudo@sgu.test': {
      id: 'user-owner',
      display_name: 'Lan (Chủ đồ)',
      verified: true,
      email: 'chudo@sgu.test',
      role: 'student',
      verification: 'approved',
      full_name: 'Nguyễn Minh Chủ',
      student_code: '3121410001',
      class_name: 'DCT1211',
      faculty: 'Công nghệ Thông tin',
      review_note: null,
    },
    'nguoithue@sgu.test': {
      id: 'user-renter',
      display_name: 'Minh (Người thuê)',
      verified: true,
      email: 'nguoithue@sgu.test',
      role: 'student',
      verification: 'approved',
      full_name: 'Trần Thị Thuê',
      student_code: '3121410002',
      class_name: 'DCT1212',
      faculty: 'Công nghệ Thông tin',
      review_note: null,
    },
    'choduyet@sgu.test': {
      id: 'user-pending',
      display_name: 'Sinh viên chờ duyệt',
      verified: false,
      email: 'choduyet@sgu.test',
      role: 'student',
      verification: 'pending',
      full_name: 'Lê Văn Chờ',
      student_code: '3121410003',
      class_name: 'DKP1211',
      faculty: 'Kinh tế',
      review_note: null,
    },
    'admin@sgu.test': {
      id: 'user-admin',
      display_name: 'Quản trị viên SGU',
      verified: true,
      email: 'admin@sgu.test',
      role: 'admin',
      verification: 'approved',
      full_name: 'Phạm Quản Trị',
      student_code: 'ADMIN001',
      class_name: null,
      faculty: 'Văn phòng Pilot',
      review_note: null,
    },
  };

  constructor() {
    if (typeof window !== 'undefined') {
      this.token = window.localStorage.getItem(STORAGE_TOKEN_KEY);
      this.mockMode = window.localStorage.getItem(STORAGE_MODE_KEY) === 'true';
    }
  }

  get accessToken(): string | null {
    return this.token;
  }

  setAccessToken(token: string | null) {
    this.token = token;
    if (typeof window !== 'undefined') {
      if (token) window.localStorage.setItem(STORAGE_TOKEN_KEY, token);
      else window.localStorage.removeItem(STORAGE_TOKEN_KEY);
    }
  }

  get isMock(): boolean {
    return this.mockMode;
  }

  setMockMode(val: boolean) {
    this.mockMode = val;
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(STORAGE_MODE_KEY, val ? 'true' : 'false');
    }
  }

  private async request<T>(
    method: string,
    path: string,
    options?: {
      query?: Record<string, string | number | boolean | undefined>;
      body?: unknown;
      idempotencyKey?: string;
    },
  ): Promise<T> {
    const params = new URLSearchParams();
    if (options?.query) {
      for (const [k, v] of Object.entries(options.query)) {
        if (v !== undefined && v !== '') params.set(k, String(v));
      }
    }
    const qs = params.toString();
    const url = `/v1${path}${qs ? `?${qs}` : ''}`;

    const headers: Record<string, string> = {};
    if (options?.body !== undefined) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }
    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }
    if (options?.idempotencyKey) {
      headers['Idempotency-Key'] = options.idempotencyKey;
    }

    let res: Response;
    try {
      res = await fetch(url, {
        method,
        headers,
        body: options?.body !== undefined ? JSON.stringify(options.body) : undefined,
      });
    } catch {
      throw new ApiClientError(
        0,
        'network_error',
        'Không thể kết nối máy chủ (/v1). Dữ liệu bạn đang nhập vẫn được giữ lại — vui lòng kiểm tra mạng và thử lại.',
      );
    }

    if (res.status === 204) {
      return {} as T;
    }

    let data: any = null;
    try {
      data = await res.json();
    } catch {
      data = null;
    }

    if (res.ok) {
      return data as T;
    }

    const retryAfter = Number(res.headers.get('retry-after') || '0') || undefined;
    const errObj = data?.error;
    throw new ApiClientError(
      res.status,
      errObj?.code || (res.status === 401 ? 'unauthenticated' : 'http_error'),
      errObj?.message || `Lỗi máy chủ (${res.status})`,
      errObj?.fields || {},
      retryAfter,
    );
  }

  async requestOtp(email: string): Promise<{ challenge_id: string; expires_at: string }> {
    if (this.mockMode) {
      return {
        challenge_id: `mock-ch-${email.trim().toLowerCase()}`,
        expires_at: new Date(Date.now() + 600000).toISOString(),
      };
    }
    return this.request('POST', '/auth/otp', { body: { email } });
  }

  async verifyOtp(
    challenge_id: string,
    code: string,
  ): Promise<{ access_token: string; expires_at: string; me: Me }> {
    if (this.mockMode) {
      const email = challenge_id.replace('mock-ch-', '');
      const u = this.mockUsers[email] || {
        ...this.mockMe,
        email,
        display_name: email.split('@')[0],
      };
      this.mockMe = u;
      this.setAccessToken(`mock-token-${u.id}`);
      return {
        access_token: `mock-token-${u.id}`,
        expires_at: new Date(Date.now() + 86400000).toISOString(),
        me: u,
      };
    }
    const res = await this.request<{ access_token: string; expires_at: string; me: Me }>(
      'POST',
      '/auth/verify',
      { body: { challenge_id, code } },
    );
    this.setAccessToken(res.access_token);
    return res;
  }

  async logout(): Promise<void> {
    if (!this.mockMode && this.token) {
      try {
        await this.request('POST', '/auth/logout', { body: {} });
      } catch {
        // ignore logout error
      }
    }
    this.setAccessToken(null);
  }

  async getMe(): Promise<Me> {
    if (this.mockMode) return this.mockMe;
    return this.request('GET', '/me');
  }

  async submitVerification(payload: {
    full_name: string;
    student_code: string;
    class_name: string;
    faculty: string;
    display_name: string;
  }): Promise<Me> {
    if (this.mockMode) {
      this.mockMe = {
        ...this.mockMe,
        ...payload,
        verification: 'pending',
        verified: false,
      };
      return this.mockMe;
    }
    return this.request('PUT', '/me/verification', { body: payload });
  }

  async getCatalogOptions(): Promise<{ categories: string[]; areas: string[] }> {
    if (this.mockMode) {
      return {
        categories: [
          'Điện tử & Máy ảnh',
          'Học tập & Sách',
          'Thể thao & Dã ngoại',
          'Nhạc cụ',
          'Đồ gia dụng',
          'Khác',
        ],
        areas: ['Cơ sở 1', 'Cơ sở 2', 'Cơ sở Chính'],
      };
    }
    return this.request('GET', '/catalog/options');
  }

  async listListings(filters?: {
    q?: string;
    category?: string;
    area?: string;
    max_daily_rate?: number;
    start_date?: string;
    end_date?: string;
    mine?: boolean;
  }): Promise<Page<Listing>> {
    return this.request('GET', '/listings', { query: filters });
  }

  async getListing(id: string): Promise<Listing> {
    return this.request('GET', `/listings/${id}`);
  }

  async createListing(input: ListingInput, idemKey = newIdempotencyKey()): Promise<Listing> {
    return this.request('POST', '/listings', {
      body: input,
      idempotencyKey: idemKey,
    });
  }

  async patchListing(id: string, patch: Partial<ListingInput>): Promise<Listing> {
    return this.request('PATCH', `/listings/${id}`, { body: patch });
  }

  async getAvailability(id: string, start_date: string, end_date: string): Promise<{ unavailable: DateRange[] }> {
    return this.request('GET', `/listings/${id}/availability`, {
      query: { start_date, end_date },
    });
  }

  async listBlocks(listingId: string): Promise<Page<Block>> {
    return this.request('GET', `/listings/${listingId}/blocks`);
  }

  async createBlock(
    listingId: string,
    range: DateRange,
    idemKey = newIdempotencyKey(),
  ): Promise<Block> {
    return this.request('POST', `/listings/${listingId}/blocks`, {
      body: range,
      idempotencyKey: idemKey,
    });
  }

  async deleteBlock(listingId: string, blockId: string): Promise<void> {
    await this.request('DELETE', `/listings/${listingId}/blocks/${blockId}`);
  }

  async quoteListing(listingId: string, range: DateRange): Promise<Quote> {
    if (this.mockMode) {
      const days = Math.max(1, calculateRentalDays(range.start_date, range.end_date));
      const daily_rate = 50000;
      const deposit = 300000;
      const rent = daily_rate * days;
      return {
        listing_id: listingId,
        listing_revision: 1,
        start_date: range.start_date,
        end_date: range.end_date,
        days,
        daily_rate,
        rent,
        deposit,
        renter_fee: 1000,
        owner_fee: 1000,
        pickup_total: rent + 1000 + deposit,
        owner_net: rent - 1000,
      };
    }
    return this.request('POST', `/listings/${listingId}/quote`, { body: range });
  }

  async uploadPhoto(
    file: File,
    purpose: 'listing' | 'handover',
    orderId?: string,
  ): Promise<{ id: string }> {
    const form = new FormData();
    form.append('purpose', purpose);
    if (orderId) form.append('order_id', orderId);
    form.append('file', file);

    const headers: Record<string, string> = {};
    if (this.token) headers['Authorization'] = `Bearer ${this.token}`;

    const res = await fetch('/v1/photos', {
      method: 'POST',
      headers,
      body: form,
    });
    const data = await res.json().catch(() => null);
    if (!res.ok) {
      throw new ApiClientError(
        res.status,
        data?.error?.code || 'upload_error',
        data?.error?.message || 'Không thể tải ảnh lên.',
        data?.error?.fields || {},
      );
    }
    return data as { id: string };
  }

  async fetchPhotoObjectUrl(photoId: string): Promise<string | null> {
    if (!this.token) return null;
    try {
      const res = await fetch(`/v1/photos/${photoId}`, {
        headers: { Authorization: `Bearer ${this.token}` },
      });
      if (!res.ok) return null;
      const blob = await res.blob();
      return URL.createObjectURL(blob);
    } catch {
      return null;
    }
  }

  async createOrder(
    payload: {
      listing_id: string;
      listing_revision: number;
      start_date: string;
      end_date: string;
      note?: string;
    },
    idemKey = newIdempotencyKey(),
  ): Promise<Order> {
    return this.request('POST', '/orders', {
      body: payload,
      idempotencyKey: idemKey,
    });
  }

  async listOrders(asRole: 'owner' | 'renter', status?: string): Promise<Page<Order>> {
    return this.request('GET', '/orders', {
      query: { as: asRole, status },
    });
  }

  async getOrder(id: string): Promise<Order> {
    return this.request('GET', `/orders/${id}`);
  }

  async approveOrder(id: string, idemKey = newIdempotencyKey()): Promise<Order> {
    return this.request('POST', `/orders/${id}/approve`, {
      body: {},
      idempotencyKey: idemKey,
    });
  }

  async rejectOrder(id: string, reason: string, idemKey = newIdempotencyKey()): Promise<Order> {
    return this.request('POST', `/orders/${id}/reject`, {
      body: { reason },
      idempotencyKey: idemKey,
    });
  }

  async cancelOrder(id: string, reason: string, idemKey = newIdempotencyKey()): Promise<Order> {
    return this.request('POST', `/orders/${id}/cancel`, {
      body: { reason },
      idempotencyKey: idemKey,
    });
  }

  async pickupOrder(
    id: string,
    payload: {
      condition: string;
      accessories: string[];
      photo_ids: string[];
      cash_received: number;
    },
    idemKey = newIdempotencyKey(),
  ): Promise<Order> {
    return this.request('POST', `/orders/${id}/pickup`, {
      body: payload,
      idempotencyKey: idemKey,
    });
  }

  async returnOrder(
    id: string,
    payload: {
      condition: string;
      accessories: string[];
      photo_ids: string[];
    },
    idemKey = newIdempotencyKey(),
  ): Promise<Order> {
    return this.request('POST', `/orders/${id}/return`, {
      body: payload,
      idempotencyKey: idemKey,
    });
  }

  async depositOrder(
    id: string,
    payload: {
      refunded: number;
      reason?: string;
    },
    idemKey = newIdempotencyKey(),
  ): Promise<Order> {
    return this.request('POST', `/orders/${id}/deposit`, {
      body: payload,
      idempotencyKey: idemKey,
    });
  }

  async listMessages(orderId: string): Promise<Page<Message>> {
    return this.request('GET', `/orders/${orderId}/messages`);
  }

  async sendMessage(
    orderId: string,
    text: string,
    idemKey = newIdempotencyKey(),
  ): Promise<Message> {
    return this.request('POST', `/orders/${orderId}/messages`, {
      body: { text },
      idempotencyKey: idemKey,
    });
  }

  async createCase(
    payload: {
      target_type: 'listing' | 'order';
      target_id: string;
      category: string;
      detail: string;
    },
    idemKey = newIdempotencyKey(),
  ): Promise<Case> {
    return this.request('POST', '/cases', {
      body: payload,
      idempotencyKey: idemKey,
    });
  }

  async listCases(): Promise<Page<Case>> {
    return this.request('GET', '/cases');
  }

  async getFeesSummary(): Promise<FeeSummary> {
    return this.request('GET', '/fees/summary');
  }

  async getFeeEntries(state?: string): Promise<Page<FeeEntry>> {
    return this.request('GET', '/fees/entries', { query: { state } });
  }

  async listSettlements(): Promise<Page<Settlement>> {
    return this.request('GET', '/settlements');
  }

  async listNotifications(): Promise<Page<Notice>> {
    return this.request('GET', '/notifications');
  }

  async markNotificationRead(id: string): Promise<Notice> {
    return this.request('PUT', `/notifications/${id}/read`, { body: {} });
  }

  // Admin endpoints (Q01 - Q03)
  async adminListVerifications(verification = 'pending'): Promise<Page<Me>> {
    return this.request('GET', '/admin/verifications', { query: { verification } });
  }

  async adminReviewVerification(
    userId: string,
    decision: 'approve' | 'reject',
    note?: string,
    idemKey = newIdempotencyKey(),
  ): Promise<Me> {
    return this.request('POST', `/admin/verifications/${userId}/review`, {
      body: { decision, note },
      idempotencyKey: idemKey,
    });
  }

  async adminListCases(status?: string, target_type?: string): Promise<Page<Case>> {
    return this.request('GET', '/admin/cases', { query: { status, target_type } });
  }

  async adminResolveCase(
    caseId: string,
    payload: {
      resolution: string;
      refunded?: number;
      handover_outcome?: 'resume' | 'cancel_unhanded';
    },
    idemKey = newIdempotencyKey(),
  ): Promise<Case> {
    return this.request('POST', `/admin/cases/${caseId}/resolve`, {
      body: payload,
      idempotencyKey: idemKey,
    });
  }

  async adminListFeeOwners(): Promise<Page<OwnerFees>> {
    return this.request('GET', '/admin/fees/owners');
  }

  async adminListOwnerFeeEntries(ownerId: string, state?: string): Promise<Page<FeeEntry>> {
    return this.request('GET', `/admin/fees/owners/${ownerId}/entries`, { query: { state } });
  }

  async adminCreateSettlement(
    payload: {
      owner_id: string;
      order_ids: string[];
      received_amount: number;
      reference: string;
    },
    idemKey = newIdempotencyKey(),
  ): Promise<Settlement> {
    return this.request('POST', '/admin/settlements', {
      body: payload,
      idempotencyKey: idemKey,
    });
  }
}

export const api = new RentWebClient();
