'use client';

import React, { useEffect, useState } from 'react';
import { api, ApiClientError } from '@/lib/api';
import {
  calculateRentalDays,
  formatShortDateRange,
  formatVnd,
  SAFE_PICKUP_SPOTS,
} from '@/lib/format';
import type { Block, DateRange, Listing, ListingInput, Me, Quote } from '@/lib/types';
import { AuthPhoto } from './AuthPhoto';

const CAMPUSES = ['Cơ sở 1', 'Cơ sở 2', 'Cơ sở Chính'];
const CATEGORIES = [
  'Điện tử & Máy ảnh',
  'Học tập & Sách',
  'Thể thao & Dã ngoại',
  'Nhạc cụ',
  'Đồ gia dụng',
  'Khác',
];

const DRAFT_STORAGE_KEY = 'sgu_rent_listing_draft_v1';

interface ExploreScreenProps {
  me: Me | null;
  unreadCount: number;
  startDate: string;
  endDate: string;
  onChangeDates: (start: string, end: string) => void;
  onSelectListing: (id: string) => void;
  onOpenNotifications: () => void;
  onOpenLogin: () => void;
}

export function ExploreScreen({
  me,
  unreadCount,
  startDate,
  endDate,
  onChangeDates,
  onSelectListing,
  onOpenNotifications,
  onOpenLogin,
}: ExploreScreenProps) {
  const [searchQ, setSearchQ] = useState('');
  const [campus, setCampus] = useState<string>('all');
  const [category, setCategory] = useState<string>('');
  const [under100k, setUnder100k] = useState(false);
  const [showDateEditor, setShowDateEditor] = useState(false);

  const [listings, setListings] = useState<Listing[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadListings = async () => {
    if (!me && !api.accessToken) return;
    setLoading(true);
    setError(null);
    try {
      const page = await api.listListings({
        q: searchQ.trim() || undefined,
        area: campus === 'all' ? undefined : campus,
        category: category || undefined,
        max_daily_rate: under100k ? 100000 : undefined,
        start_date: startDate,
        end_date: endDate,
      });
      setListings(page.items);
    } catch (e: any) {
      setError(e?.message || 'Không thể tải danh sách món đồ.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (me || api.accessToken) {
      loadListings();
    }
  }, [me, campus, category, under100k, startDate, endDate]);

  return (
    <div className="flex flex-col pb-24">
      {/* Top App Bar (S03) */}
      <header className="sticky top-0 z-20 bg-light-surface border-b border-light-outline-variant px-page-margin py-gutter-sm flex items-center justify-between gap-gutter-sm">
        <div className="flex items-center gap-gutter-sm">
          <div className="w-9 h-9 rounded-md bg-light-primary text-light-on-primary flex items-center justify-center shrink-0">
            <span className="material-symbols-outlined text-[20px]">school</span>
          </div>
          <div className="flex flex-col">
            <h1 className="font-title text-title-md text-light-on-surface">
              Thuê Đồ Sinh Viên
            </h1>
            <span className="font-label text-label-sm text-light-on-surface-variant">
              Đại học Sài Gòn · Cơ sở 1 · 2 · Chính
            </span>
          </div>
        </div>

        <div className="flex items-center gap-gutter-xs">
          {!me && (
            <button
              type="button"
              onClick={onOpenLogin}
              className="min-h-[40px] px-4 rounded-full bg-light-primary text-light-on-primary font-label text-label-md"
            >
              Đăng nhập
            </button>
          )}
          <button
            type="button"
            onClick={onOpenNotifications}
            aria-label="Hộp thông báo"
            className="relative inline-flex items-center justify-center w-12 h-12 rounded-full text-light-on-surface hover:bg-light-surface-container"
          >
            <span className="material-symbols-outlined text-[24px]">notifications</span>
            {unreadCount > 0 && (
              <span className="absolute top-2 right-2 inline-flex items-center justify-center min-w-5 h-5 px-1 rounded-full bg-light-error text-light-on-error font-label text-label-sm tabular-nums">
                {unreadCount}
              </span>
            )}
          </button>
        </div>
      </header>

      <main className="flex-1 flex flex-col gap-gutter-md px-page-margin pt-gutter-md">
        {/* Search & Date Range Section */}
        <section aria-label="Tìm kiếm và chọn ngày" className="flex flex-col gap-gutter-sm">
          <form
            role="search"
            onSubmit={(e) => {
              e.preventDefault();
              loadListings();
            }}
            className="flex items-center gap-gutter-sm min-h-[48px] px-4 rounded-full bg-light-surface-container-lowest border border-light-outline-variant focus-within:border-light-primary transition-colors"
          >
            <span className="material-symbols-outlined text-[20px] text-light-on-surface-variant">
              search
            </span>
            <input
              type="search"
              value={searchQ}
              onChange={(e) => setSearchQ(e.target.value)}
              aria-label="Tìm món đồ cần thuê"
              placeholder="Tìm máy ảnh, máy tính Casio, lều..."
              className="w-full bg-transparent border-0 p-0 font-body text-body-md text-light-on-surface placeholder:text-light-outline focus:outline-none"
            />
            <button
              type="submit"
              aria-label="Tìm kiếm"
              className="inline-flex items-center justify-center w-9 h-9 rounded-full text-light-primary hover:bg-light-surface-container"
            >
              <span className="material-symbols-outlined text-[20px]">tune</span>
            </button>
          </form>

          {/* Date Range & Price Quick Row */}
          <div className="flex items-center gap-gutter-sm overflow-x-auto pb-1">
            <button
              type="button"
              onClick={() => setShowDateEditor((v) => !v)}
              className="shrink-0 inline-flex items-center gap-gutter-xs min-h-[40px] px-3.5 py-2 rounded-full bg-light-secondary-container text-light-on-secondary-container font-label text-label-md tabular-nums"
            >
              <span className="material-symbols-outlined text-[18px]">calendar_today</span>
              <span>{formatShortDateRange(startDate, endDate)}</span>
            </button>

            <button
              type="button"
              onClick={() => setUnder100k((v) => !v)}
              className={`shrink-0 inline-flex items-center gap-gutter-xs min-h-[40px] px-3.5 py-2 rounded-full font-label text-label-md border ${
                under100k
                  ? 'bg-light-secondary-container text-light-on-secondary-container border-transparent'
                  : 'bg-light-surface-container-lowest text-light-on-surface-variant border-light-outline-variant'
              }`}
            >
              {under100k && <span className="material-symbols-outlined text-[18px]">check</span>}
              <span>Dưới 100.000đ</span>
            </button>

            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              aria-label="Lọc theo loại đồ"
              className="shrink-0 min-h-[40px] px-3.5 py-2 rounded-full bg-light-surface-container-lowest border border-light-outline-variant font-label text-label-md text-light-on-surface-variant"
            >
              <option value="">Tất cả loại đồ</option>
              {CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </div>

          {showDateEditor && (
            <div className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md grid grid-cols-1 sm:grid-cols-2 gap-gutter-sm">
              <div className="flex flex-col gap-1">
                <label className="font-label text-label-sm text-light-on-surface-variant">
                  Ngày nhận đồ
                </label>
                <input
                  type="date"
                  value={startDate}
                  onChange={(e) => {
                    const nextStart = e.target.value;
                    onChangeDates(nextStart, nextStart > endDate ? nextStart : endDate);
                  }}
                  className="min-h-[44px] px-3 rounded-md border border-light-outline-variant font-mono text-body-md"
                />
              </div>
              <div className="flex flex-col gap-1">
                <label className="font-label text-label-sm text-light-on-surface-variant">
                  Ngày trả đồ (tính cả 2 đầu ngày)
                </label>
                <input
                  type="date"
                  value={endDate}
                  min={startDate}
                  onChange={(e) => onChangeDates(startDate, e.target.value)}
                  className="min-h-[44px] px-3 rounded-md border border-light-outline-variant font-mono text-body-md"
                />
              </div>
            </div>
          )}

          {/* Campus Filter Chips */}
          <div
            className="flex items-center gap-gutter-sm overflow-x-auto pb-1"
            role="group"
            aria-label="Lọc theo cơ sở"
          >
            {['all', ...CAMPUSES].map((c) => {
              const selected = campus === c;
              return (
                <button
                  key={c}
                  type="button"
                  onClick={() => setCampus(c)}
                  className={`shrink-0 inline-flex items-center gap-gutter-xs min-h-[40px] px-3.5 py-2 rounded-full font-label text-label-md transition-colors ${
                    selected
                      ? 'bg-light-secondary-container text-light-on-secondary-container border border-transparent'
                      : 'bg-light-surface-container-lowest text-light-on-surface-variant border border-light-outline-variant hover:bg-light-surface-container-low'
                  }`}
                >
                  {selected && (
                    <span className="material-symbols-outlined text-[18px]">check</span>
                  )}
                  <span>{c === 'all' ? 'Tất cả cơ sở' : c}</span>
                </button>
              );
            })}
          </div>
        </section>

        {!me ? (
          <div className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-lg flex flex-col items-center text-center gap-gutter-sm">
            <span className="material-symbols-outlined text-[32px] text-light-primary">
              verified_user
            </span>
            <h2 className="font-title text-title-lg text-light-on-surface">
              Đăng nhập bằng Email OTP để khám phá món đồ trống lịch
            </h2>
            <p className="font-body text-body-md text-light-on-surface-variant max-w-md">
              Theo quy định bảo mật, danh mục tin đăng chỉ mở cho sinh viên ĐH Sài Gòn đã xác thực email (kể cả tài khoản đang chờ duyệt thẻ).
            </p>
            <button
              type="button"
              onClick={onOpenLogin}
              className="min-h-[48px] px-6 rounded-full bg-light-primary text-light-on-primary font-label text-label-lg"
            >
              Đăng nhập sinh viên ngay
            </button>
          </div>
        ) : (
          <>
            {/* Availability Summary Header */}
            <div className="flex items-center justify-between gap-gutter-sm">
              <h2 className="font-title text-title-md text-light-on-surface">
                Món trống toàn khoảng ngày
              </h2>
              <span className="font-label text-label-md text-light-on-surface-variant tabular-nums">
                {listings.length} món
              </span>
            </div>

            {error && (
              <div className="rounded-lg bg-light-error-container text-light-on-error-container p-gutter-md flex items-center justify-between">
                <span className="font-body text-body-md">{error}</span>
                <button
                  type="button"
                  onClick={loadListings}
                  className="px-3 py-1.5 rounded-full bg-light-surface-container-lowest text-light-on-surface font-label text-label-sm"
                >
                  Thử lại
                </button>
              </div>
            )}

            {loading ? (
              <div className="py-12 text-center font-body text-body-md text-light-on-surface-variant">
                Đang tìm món trống lịch...
              </div>
            ) : listings.length === 0 ? (
              <div className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-lg flex flex-col items-center text-center gap-gutter-sm">
                <span className="material-symbols-outlined text-[28px] text-light-on-surface-variant">
                  event_busy
                </span>
                <h3 className="font-title text-title-md text-light-on-surface">
                  Không có món trống theo bộ lọc này
                </h3>
                <p className="font-body text-body-md text-light-on-surface-variant">
                  Các món phù hợp đã có lịch giữ trong khoảng {formatShortDateRange(startDate, endDate)}.
                </p>
                <div className="flex flex-wrap items-center justify-center gap-gutter-sm pt-2">
                  <button
                    type="button"
                    onClick={() => setShowDateEditor(true)}
                    className="min-h-[44px] px-4 rounded-full bg-light-secondary-container text-light-on-secondary-container font-label text-label-md"
                  >
                    Đổi ngày thuê
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setSearchQ('');
                      setCampus('all');
                      setCategory('');
                      setUnder100k(false);
                    }}
                    className="min-h-[44px] px-4 rounded-full border border-light-outline-variant font-label text-label-md text-light-primary"
                  >
                    Xóa bộ lọc
                  </button>
                </div>
              </div>
            ) : (
              /* 2-Column Mobile / 3-4 Column Desktop 4:3 Item Grid */
              <section
                aria-label="Danh sách món cho thuê"
                className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-gutter-sm items-stretch"
              >
                {listings.map((item) => (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => onSelectListing(item.id)}
                    className="text-left h-full rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-sm flex flex-col gap-gutter-sm hover:border-light-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-light-primary transition-colors"
                  >
                    <div className="w-full aspect-[4/3] rounded-md overflow-hidden bg-light-surface-container">
                      <AuthPhoto
                        photoIds={item.photo_ids}
                        fallbackKey={item.id}
                        alt={item.title}
                      />
                    </div>
                    <div className="flex-1 flex flex-col justify-between gap-gutter-xs">
                      <h3 className="font-title text-title-md text-light-on-surface truncate">
                        {item.title}
                      </h3>
                      <div className="flex flex-col gap-gutter-xs">
                        <p className="font-label text-label-lg text-light-primary tabular-nums">
                          {formatVnd(item.daily_rate)}/ngày
                        </p>
                        <div className="flex items-center justify-between gap-1 text-light-on-surface-variant">
                          <div className="flex items-center gap-gutter-xs">
                            <span className="material-symbols-outlined text-[16px]">
                              location_on
                            </span>
                            <span className="font-label text-label-sm">{item.area}</span>
                          </div>
                          {item.owner.verified && (
                            <span
                              title="Chủ đồ đã xác minh thẻ SV"
                              className="material-symbols-outlined text-[15px] text-success material-fill"
                            >
                              verified
                            </span>
                          )}
                        </div>
                      </div>
                    </div>
                  </button>
                ))}
              </section>
            )}
          </>
        )}
      </main>
    </div>
  );
}

interface ListingDetailScreenProps {
  listingId: string;
  me: Me | null;
  startDate: string;
  endDate: string;
  onChangeDates: (start: string, end: string) => void;
  onBack: () => void;
  onEditListing: (listing: Listing) => void;
  onManageSchedule: (listing: Listing) => void;
  onOrderCreated: (orderId: string) => void;
  onReportListing: (listingId: string) => void;
  onRequireVerification: () => void;
}

export function ListingDetailScreen({
  listingId,
  me,
  startDate,
  endDate,
  onChangeDates,
  onBack,
  onEditListing,
  onManageSchedule,
  onOrderCreated,
  onReportListing,
  onRequireVerification,
}: ListingDetailScreenProps) {
  const [listing, setListing] = useState<Listing | null>(null);
  const [quote, setQuote] = useState<Quote | null>(null);
  const [unavailable, setUnavailable] = useState<DateRange[]>([]);
  const [note, setNote] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadDetailAndQuote = async (sDate = startDate, eDate = endDate) => {
    setLoading(true);
    setError(null);
    try {
      const [item, q, avail] = await Promise.all([
        api.getListing(listingId),
        api.quoteListing(listingId, { start_date: sDate, end_date: eDate }),
        api.getAvailability(listingId, '2026-01-01', '2027-12-31'),
      ]);
      setListing(item);
      setQuote(q);
      setUnavailable(avail.unavailable);
    } catch (e: any) {
      setError(e?.message || 'Không thể tải thông tin món đồ.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadDetailAndQuote(startDate, endDate);
  }, [listingId, startDate, endDate]);

  if (loading || !listing) {
    return (
      <div className="p-gutter-lg text-center font-body text-body-md text-light-on-surface-variant">
        {error || 'Đang tải chi tiết món đồ...'}
      </div>
    );
  }

  const isOwner = me?.id === listing.owner.id;
  const safeSpots = SAFE_PICKUP_SPOTS[listing.area] || SAFE_PICKUP_SPOTS['Cơ sở Chính'];

  const handleSendOrder = async () => {
    if (!me || me.verification !== 'approved') {
      onRequireVerification();
      return;
    }
    if (!quote) return;
    setBusy(true);
    setError(null);
    try {
      const created = await api.createOrder({
        listing_id: listing.id,
        listing_revision: quote.listing_revision,
        start_date: startDate,
        end_date: endDate,
        note: note.trim() || undefined,
      });
      onOrderCreated(created.id);
    } catch (e: any) {
      if (e instanceof ApiClientError && e.code === 'quote_changed') {
        setError(
          'Chủ đồ vừa cập nhật giá hoặc phụ kiện của tin này. Đã tải lại báo giá mới — vui lòng kiểm tra trước khi gửi lại.',
        );
        await loadDetailAndQuote();
      } else {
        setError(e?.message || 'Không thể gửi yêu cầu thuê.');
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col pb-28">
      <header className="sticky top-0 z-20 bg-light-surface border-b border-light-outline-variant px-gutter-sm py-gutter-xs flex items-center justify-between gap-gutter-sm">
        <div className="flex items-center gap-gutter-xs">
          <button
            type="button"
            onClick={onBack}
            aria-label="Quay lại Khám phá"
            className="inline-flex items-center justify-center w-12 h-12 rounded-full text-light-on-surface hover:bg-light-surface-container"
          >
            <span className="material-symbols-outlined text-[24px]">arrow_back</span>
          </button>
          <h1 className="font-title text-title-lg text-light-on-surface">S04 · Chi tiết món</h1>
        </div>
        <button
          type="button"
          onClick={() => onReportListing(listing.id)}
          aria-label="Báo cáo tin đăng"
          className="inline-flex items-center justify-center w-12 h-12 rounded-full text-light-on-surface hover:bg-light-surface-container"
        >
          <span className="material-symbols-outlined text-[22px]">flag</span>
        </button>
      </header>

      <main className="flex-1 flex flex-col gap-gutter-md px-page-margin pt-gutter-md">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-gutter-lg items-start">
          {/* Left column: Photo, Info, Owner Trust Card */}
          <div className="lg:col-span-7 flex flex-col gap-gutter-md">
            <div className="relative w-full aspect-[4/3] rounded-lg overflow-hidden bg-light-surface-container border border-light-outline-variant">
              <AuthPhoto
                photoIds={listing.photo_ids}
                fallbackKey={listing.id}
                alt={listing.title}
              />
              <span className="absolute bottom-3 right-3 px-2.5 py-1 rounded-full bg-light-inverse-surface text-light-inverse-on-surface font-label text-label-sm tabular-nums">
                Phiên bản tin #{listing.revision}
              </span>
            </div>

            <section className="flex flex-col gap-gutter-sm">
              <div className="flex flex-wrap items-center gap-gutter-sm">
                <span className="inline-flex items-center gap-gutter-xs px-2.5 py-1 rounded-full bg-light-surface-container text-light-on-surface-variant">
                  <span className="material-symbols-outlined text-[14px]">location_on</span>
                  <span className="font-label text-label-sm">{listing.area}</span>
                </span>
                <span className="inline-flex items-center gap-gutter-xs px-2.5 py-1 rounded-full bg-light-surface-container text-light-on-surface-variant">
                  <span className="font-label text-label-sm">
                    Tình trạng: {listing.condition}
                  </span>
                </span>
              </div>

              <h2 className="font-headline text-headline-md text-light-on-surface">
                {listing.title}
              </h2>

              <div className="flex items-baseline gap-gutter-md">
                <p className="font-headline text-headline-md text-light-primary tabular-nums">
                  {formatVnd(listing.daily_rate)}
                  <span className="font-body text-body-md text-light-on-surface-variant">
                    /ngày
                  </span>
                </p>
                <p className="font-label text-label-lg text-light-tertiary tabular-nums">
                  Cọc: {formatVnd(listing.deposit)}
                </p>
              </div>
            </section>

            {/* Owner Verification & Academic Trust Block */}
            <section
              aria-label="Thông tin chủ đồ"
              className="rounded-lg bg-light-surface-container-low border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-xs"
            >
              <div className="flex items-center justify-between gap-gutter-sm">
                <div className="flex items-center gap-gutter-sm">
                  <div className="w-11 h-11 rounded-full bg-light-primary text-light-on-primary flex items-center justify-center font-title text-title-md">
                    {listing.owner.display_name.slice(0, 1).toUpperCase()}
                  </div>
                  <div className="flex flex-col gap-0.5">
                    <div className="flex items-center gap-gutter-xs flex-wrap">
                      <span className="font-title text-title-md text-light-on-surface">
                        {listing.owner.display_name}
                      </span>
                      {listing.owner.verified && (
                        <span className="inline-flex items-center gap-gutter-xs px-2 py-0.5 rounded-full bg-success-container text-on-success-container">
                          <span className="material-symbols-outlined text-[13px] material-fill">
                            verified
                          </span>
                          <span className="font-label text-label-sm">
                            Đã xác minh thẻ SV ĐHSG
                          </span>
                        </span>
                      )}
                    </div>
                    <span className="font-body text-body-md text-light-on-surface-variant">
                      Chủ đồ · Hẹn giao trực tiếp tại {listing.area}
                    </span>
                  </div>
                </div>
              </div>
              <div className="pt-gutter-xs border-t border-light-outline-variant font-label text-label-sm text-light-on-surface-variant">
                Điểm hẹn an toàn gợi ý tại {listing.area}: {safeSpots.join(' · ')}
              </div>
            </section>

            {/* Description & Accessories */}
            <section className="flex flex-col gap-gutter-sm">
              <h3 className="font-title text-title-md text-light-on-surface">
                Mô tả & phụ kiện kèm theo
              </h3>
              <p className="font-body text-body-md text-light-on-surface-variant">
                {listing.description}
              </p>
              <div className="rounded-md bg-light-surface-container-lowest border border-light-outline-variant p-gutter-sm flex items-start gap-gutter-sm">
                <span className="material-symbols-outlined text-[20px] text-light-primary mt-0.5">
                  inventory_2
                </span>
                <div className="flex flex-col gap-0.5">
                  <span className="font-label text-label-md text-light-on-surface">
                    Phụ kiện bàn giao
                  </span>
                  <span className="font-body text-body-md text-light-on-surface-variant">
                    {listing.accessories.join(', ') || 'Không có phụ kiện đi kèm'}
                  </span>
                </div>
              </div>
            </section>
          </div>

          {/* Right column: Date Selection, Busy Calendar, Financial Quote Card */}
          <div className="lg:col-span-5 flex flex-col gap-gutter-md">
            {isOwner && (
              <section className="rounded-lg bg-light-secondary-container text-light-on-secondary-container p-gutter-md flex flex-col gap-gutter-sm">
                <span className="font-title text-title-md">Bạn là chủ của món đồ này</span>
                <div className="flex flex-wrap gap-gutter-sm">
                  <button
                    type="button"
                    onClick={() => onEditListing(listing)}
                    className="min-h-[40px] px-4 rounded-full bg-light-primary text-light-on-primary font-label text-label-md"
                  >
                    Sửa thông tin & giá
                  </button>
                  <button
                    type="button"
                    onClick={() => onManageSchedule(listing)}
                    className="min-h-[40px] px-4 rounded-full bg-light-surface-container-lowest text-light-on-surface font-label text-label-md"
                  >
                    Quản lý lịch bận
                  </button>
                </div>
              </section>
            )}

            {/* Public Availability & Date Picker */}
            <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
              <div className="flex items-center justify-between">
                <h3 className="font-title text-title-md text-light-on-surface">
                  Chọn ngày nhận – trả
                </h3>
                <span className="font-label text-label-sm text-light-primary tabular-nums">
                  Đã chọn {calculateRentalDays(startDate, endDate)} ngày
                </span>
              </div>

              <div className="grid grid-cols-2 gap-gutter-sm">
                <div className="flex flex-col gap-1">
                  <label className="font-label text-label-sm text-light-on-surface-variant">
                    Ngày nhận
                  </label>
                  <input
                    type="date"
                    value={startDate}
                    onChange={(e) => {
                      const s = e.target.value;
                      onChangeDates(s, s > endDate ? s : endDate);
                    }}
                    className="min-h-[44px] px-3 rounded-md border border-light-outline-variant font-mono text-body-md"
                  />
                </div>
                <div className="flex flex-col gap-1">
                  <label className="font-label text-label-sm text-light-on-surface-variant">
                    Ngày trả
                  </label>
                  <input
                    type="date"
                    value={endDate}
                    min={startDate}
                    onChange={(e) => onChangeDates(startDate, e.target.value)}
                    className="min-h-[44px] px-3 rounded-md border border-light-outline-variant font-mono text-body-md"
                  />
                </div>
              </div>

              {unavailable.length > 0 && (
                <div className="pt-gutter-xs border-t border-light-outline-variant flex flex-col gap-1">
                  <span className="font-label text-label-sm text-light-on-surface-variant">
                    Các khoảng ngày đã bận (không lộ danh tính người thuê):
                  </span>
                  <div className="flex flex-wrap gap-1">
                    {unavailable.map((r, idx) => (
                      <span
                        key={idx}
                        className="px-2 py-0.5 rounded bg-light-surface-container text-light-on-surface-variant font-mono text-label-sm line-through tabular-nums"
                      >
                        {r.start_date} → {r.end_date}
                      </span>
                    ))}
                  </div>
                </div>
              )}
            </section>

            {/* Financial Quote Card (Brief §4) */}
            {quote && (
              <article className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
                <header className="flex items-center justify-between gap-gutter-sm">
                  <h3 className="font-title text-title-md text-light-on-surface">
                    Báo giá dự kiến
                  </h3>
                  <span className="font-label text-label-md text-light-primary tabular-nums">
                    {formatShortDateRange(quote.start_date, quote.end_date)}
                  </span>
                </header>

                <div className="flex flex-col gap-gutter-xs text-light-on-surface-variant border-t border-light-outline-variant pt-gutter-sm">
                  <div className="flex items-center justify-between gap-gutter-sm">
                    <span className="font-body text-body-md">
                      {formatVnd(quote.daily_rate)}/ngày × {quote.days} ngày
                    </span>
                    <span className="font-body text-body-md text-light-on-surface tabular-nums">
                      {formatVnd(quote.rent)}
                    </span>
                  </div>
                  <div className="flex items-center justify-between gap-gutter-sm">
                    <span className="font-body text-body-md">Phí dự kiến (người thuê)</span>
                    <span className="font-body text-body-md text-light-on-surface tabular-nums">
                      {formatVnd(quote.renter_fee)}
                    </span>
                  </div>
                  <div className="flex items-center justify-between gap-gutter-sm">
                    <span className="font-body text-body-md">Tiền cọc (hoàn khi trả đủ)</span>
                    <span className="font-body text-body-md text-light-on-surface tabular-nums">
                      {formatVnd(quote.deposit)}
                    </span>
                  </div>
                </div>

                <div className="flex items-center justify-between gap-gutter-sm border-t border-light-outline-variant pt-gutter-sm">
                  <span className="font-title text-title-md text-light-on-surface">
                    Cần mang khi nhận máy
                  </span>
                  <span className="font-headline text-headline-md text-light-primary tabular-nums">
                    {formatVnd(quote.pickup_total)}
                  </span>
                </div>
              </article>
            )}

            {error && (
              <div
                role="alert"
                className="rounded-md bg-light-error-container text-light-on-error-container p-gutter-sm font-body text-body-md"
              >
                {error}
              </div>
            )}

            {!isOwner && (
              <section className="flex flex-col gap-gutter-xs">
                <label className="font-label text-label-lg text-light-on-surface">
                  Lời nhắn cho {listing.owner.display_name} (tùy chọn)
                </label>
                <textarea
                  rows={2}
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  placeholder={`Ví dụ: Mình nhận đồ lúc 9h sáng tại ${safeSpots[0]} nhé.`}
                  className="w-full rounded-md bg-light-surface-container-lowest border border-light-outline-variant p-gutter-sm font-body text-body-md text-light-on-surface placeholder:text-light-outline focus:border-light-primary focus:outline-none"
                />
              </section>
            )}
          </div>
        </div>
      </main>

      {!isOwner && quote && (
        <footer className="fixed bottom-0 left-0 lg:left-60 right-0 z-30 bg-light-surface-container-lowest border-t border-light-outline-variant px-page-margin py-gutter-sm">
          <div className="max-w-[680px] mx-auto flex items-center justify-between gap-gutter-md">
            <div className="flex flex-col">
              <span className="font-label text-label-sm text-light-on-surface-variant">
                Cần mang khi nhận
              </span>
              <span className="font-title text-title-lg text-light-primary tabular-nums">
                {formatVnd(quote.pickup_total)}
              </span>
            </div>

            <button
              type="button"
              disabled={busy}
              onClick={handleSendOrder}
              className="flex-1 inline-flex items-center justify-center min-h-[48px] px-5 py-3 rounded-full bg-light-primary text-light-on-primary hover:bg-light-primary-container font-label text-label-lg disabled:opacity-50"
            >
              {busy ? 'Đang gửi yêu cầu...' : 'Gửi yêu cầu thuê'}
            </button>
          </div>
        </footer>
      )}
    </div>
  );
}

interface ListingFormScreenProps {
  me: Me | null;
  editingListing?: Listing | null;
  onSaved: (listingId: string) => void;
  onCancel: () => void;
  onRequireVerification: () => void;
}

export function ListingFormScreen({
  me,
  editingListing,
  onSaved,
  onCancel,
  onRequireVerification,
}: ListingFormScreenProps) {
  const [step, setStep] = useState<1 | 2 | 3>(1);
  const [title, setTitle] = useState(editingListing?.title || '');
  const [category, setCategory] = useState(editingListing?.category || CATEGORIES[0]);
  const [condition, setCondition] = useState(editingListing?.condition || 'Rất tốt');
  const [accessoriesText, setAccessoriesText] = useState(
    editingListing?.accessories.join(', ') || '1 pin, túi đựng',
  );
  const [description, setDescription] = useState(
    editingListing?.description ||
      'Món đồ hoạt động ổn định, phù hợp phục vụ đồ án và sự kiện CLB.',
  );
  const [dailyRateText, setDailyRateText] = useState(
    String(editingListing?.daily_rate ?? 50000),
  );
  const [depositText, setDepositText] = useState(
    String(editingListing?.deposit ?? 300000),
  );
  const [area, setArea] = useState(editingListing?.area || 'Cơ sở 2');
  const [photoIds, setPhotoIds] = useState<string[]>(editingListing?.photo_ids || []);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [draftNotice, setDraftNotice] = useState<string | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!editingListing && typeof window !== 'undefined') {
      const raw = window.localStorage.getItem(DRAFT_STORAGE_KEY);
      if (raw) {
        try {
          const d = JSON.parse(raw);
          if (d.title) setTitle(d.title);
          if (d.category) setCategory(d.category);
          if (d.condition) setCondition(d.condition);
          if (d.accessoriesText) setAccessoriesText(d.accessoriesText);
          if (d.description) setDescription(d.description);
          if (d.dailyRateText) setDailyRateText(d.dailyRateText);
          if (d.depositText) setDepositText(d.depositText);
          if (d.area) setArea(d.area);
          if (Array.isArray(d.photoIds)) setPhotoIds(d.photoIds);
          setDraftNotice('Đã khôi phục bản nháp lưu trên thiết bị.');
        } catch {
          // ignore
        }
      }
    }
  }, [editingListing]);

  if (!me || me.verification !== 'approved') {
    return (
      <div className="p-gutter-lg flex flex-col items-center text-center gap-gutter-md">
        <span className="material-symbols-outlined text-[36px] text-light-primary">
          verified_user
        </span>
        <h2 className="font-title text-title-lg text-light-on-surface">
          Cần xác minh thẻ sinh viên để đăng đồ cho thuê
        </h2>
        <p className="font-body text-body-md text-light-on-surface-variant max-w-md">
          Tài khoản chờ duyệt chỉ có thể xem danh mục món đồ. Vui lòng hoàn tất thông tin xác minh sinh viên trước khi đăng tin.
        </p>
        <button
          type="button"
          onClick={onRequireVerification}
          className="min-h-[48px] px-6 rounded-full bg-light-primary text-light-on-primary font-label text-label-lg"
        >
          Đi tới Hồ sơ & Xác minh
        </button>
      </div>
    );
  }

  const saveDraft = () => {
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(
        DRAFT_STORAGE_KEY,
        JSON.stringify({
          title,
          category,
          condition,
          accessoriesText,
          description,
          dailyRateText,
          depositText,
          area,
          photoIds,
        }),
      );
      setDraftNotice('Đã lưu nháp trên trình duyệt.');
    }
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    setUploadError(null);
    try {
      const res = await api.uploadPhoto(file, 'listing');
      setPhotoIds((prev) => [...prev, res.id]);
    } catch (err: any) {
      setUploadError(err?.message || 'Lỗi tải ảnh (chỉ hỗ trợ JPEG/PNG tối đa 8 MiB).');
    } finally {
      setUploading(false);
    }
  };

  const dailyRate = Number(dailyRateText.replace(/\D/g, '')) || 0;
  const deposit = Number(depositText.replace(/\D/g, '')) || 0;

  const handlePublish = async () => {
    setBusy(true);
    setSubmitError(null);
    const input: ListingInput = {
      title: title.trim(),
      category,
      description: description.trim(),
      condition: condition.trim(),
      accessories: accessoriesText
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean),
      photo_ids: photoIds,
      daily_rate: dailyRate,
      deposit,
      area,
      pickup_point: area,
    };
    try {
      const saved = editingListing
        ? await api.patchListing(editingListing.id, input)
        : await api.createListing(input);
      if (!editingListing && typeof window !== 'undefined') {
        window.localStorage.removeItem(DRAFT_STORAGE_KEY);
      }
      onSaved(saved.id);
    } catch (err: any) {
      setSubmitError(err?.message || 'Không thể lưu tin đăng.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col pb-28">
      <header className="sticky top-0 z-20 bg-light-surface border-b border-light-outline-variant px-gutter-sm py-gutter-xs flex items-center justify-between gap-gutter-sm">
        <div className="flex items-center gap-gutter-xs">
          <button
            type="button"
            onClick={onCancel}
            className="inline-flex items-center justify-center w-12 h-12 rounded-full text-light-on-surface hover:bg-light-surface-container"
          >
            <span className="material-symbols-outlined text-[24px]">arrow_back</span>
          </button>
          <h1 className="font-title text-title-lg text-light-on-surface">
            S05 · {editingListing ? 'Sửa tin đăng' : 'Đăng món cho thuê'}
          </h1>
        </div>
        {!editingListing && (
          <button
            type="button"
            onClick={saveDraft}
            className="px-3 py-2 rounded-full font-label text-label-md text-light-primary hover:bg-light-surface-container"
          >
            Lưu nháp
          </button>
        )}
      </header>

      {/* 3-Step Indicator */}
      <div className="px-page-margin pt-gutter-md">
        <div className="grid grid-cols-3 gap-gutter-xs" role="tablist">
          {[
            { s: 1, label: '1. Ảnh & Mô tả' },
            { s: 2, label: '2. Giá & Cọc' },
            { s: 3, label: '3. Cơ sở & Đăng' },
          ].map((item) => (
            <button
              key={item.s}
              type="button"
              onClick={() => setStep(item.s as 1 | 2 | 3)}
              className={`py-2 px-2 rounded-md font-label text-label-sm text-center ${
                step === item.s
                  ? 'bg-light-secondary-container text-light-on-secondary-container'
                  : 'bg-light-surface-container text-light-on-surface-variant'
              }`}
            >
              {item.label}
            </button>
          ))}
        </div>
      </div>

      <main className="flex-1 flex flex-col gap-gutter-md px-page-margin pt-gutter-md">
        {draftNotice && (
          <div className="rounded-md bg-light-surface-container-low p-gutter-sm font-label text-label-sm text-light-primary">
            {draftNotice}
          </div>
        )}

        {submitError && (
          <div
            role="alert"
            className="rounded-md bg-light-error-container text-light-on-error-container p-gutter-sm font-body text-body-md"
          >
            {submitError}
          </div>
        )}

        {step === 1 && (
          <section className="flex flex-col gap-gutter-md">
            <div className="flex flex-col gap-gutter-xs">
              <span className="font-label text-label-lg text-light-on-surface">
                Ảnh món đồ (4:3, JPEG/PNG tối đa 8 MiB)
              </span>
              <div className="grid grid-cols-3 gap-gutter-sm">
                {photoIds.map((pid) => (
                  <div
                    key={pid}
                    className="aspect-[4/3] rounded-md overflow-hidden border border-light-outline-variant bg-light-surface-container"
                  >
                    <AuthPhoto photoIds={[pid]} alt="Ảnh đã tải" />
                  </div>
                ))}

                <label className="aspect-[4/3] rounded-md border border-dashed border-light-outline-variant bg-light-surface-container-low flex flex-col items-center justify-center p-2 gap-1 cursor-pointer hover:border-light-primary">
                  <span className="material-symbols-outlined text-[22px] text-light-primary">
                    add_a_photo
                  </span>
                  <span className="font-label text-label-sm text-light-primary text-center">
                    {uploading ? 'Đang tải...' : 'Thêm ảnh'}
                  </span>
                  <input
                    type="file"
                    accept="image/jpeg,image/png"
                    onChange={handleFileUpload}
                    className="hidden"
                  />
                </label>
              </div>
              {uploadError && (
                <span className="font-label text-label-sm text-light-error">
                  {uploadError}
                </span>
              )}
            </div>

            <div className="flex flex-col gap-gutter-sm">
              <div className="flex flex-col gap-1">
                <label className="font-label text-label-md text-light-on-surface">
                  Tên món đồ
                </label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Ví dụ: Máy ảnh Sony ZV-E10 kèm 1 pin"
                  className="w-full min-h-[48px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md text-light-on-surface"
                />
              </div>

              <div className="grid grid-cols-2 gap-gutter-sm">
                <div className="flex flex-col gap-1">
                  <label className="font-label text-label-md text-light-on-surface">
                    Loại đồ
                  </label>
                  <select
                    value={category}
                    onChange={(e) => setCategory(e.target.value)}
                    className="w-full min-h-[48px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md text-light-on-surface"
                  >
                    {CATEGORIES.map((c) => (
                      <option key={c} value={c}>
                        {c}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="flex flex-col gap-1">
                  <label className="font-label text-label-md text-light-on-surface">
                    Tình trạng
                  </label>
                  <input
                    type="text"
                    value={condition}
                    onChange={(e) => setCondition(e.target.value)}
                    className="w-full min-h-[48px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md text-light-on-surface"
                  />
                </div>
              </div>

              <div className="flex flex-col gap-1">
                <label className="font-label text-label-md text-light-on-surface">
                  Phụ kiện kèm theo (cách nhau bằng dấu phẩy)
                </label>
                <input
                  type="text"
                  value={accessoriesText}
                  onChange={(e) => setAccessoriesText(e.target.value)}
                  className="w-full min-h-[48px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md text-light-on-surface"
                />
              </div>

              <div className="flex flex-col gap-1">
                <label className="font-label text-label-md text-light-on-surface">
                  Mô tả chi tiết
                </label>
                <textarea
                  rows={3}
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  className="w-full p-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md text-light-on-surface"
                />
              </div>
            </div>
          </section>
        )}

        {step === 2 && (
          <section className="flex flex-col gap-gutter-md">
            <div className="grid grid-cols-2 gap-gutter-sm">
              <div className="flex flex-col gap-1">
                <label className="font-label text-label-md text-light-on-surface">
                  Giá thuê/ngày (đ, tối đa 10.000.000)
                </label>
                <input
                  type="number"
                  min={0}
                  max={10000000}
                  value={dailyRateText}
                  onChange={(e) => setDailyRateText(e.target.value)}
                  className="w-full min-h-[48px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md text-light-on-surface tabular-nums"
                />
              </div>
              <div className="flex flex-col gap-1">
                <label className="font-label text-label-md text-light-on-surface">
                  Tiền cọc (đ, có thể bằng 0)
                </label>
                <input
                  type="number"
                  min={0}
                  max={50000000}
                  value={depositText}
                  onChange={(e) => setDepositText(e.target.value)}
                  className="w-full min-h-[48px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md text-light-on-surface tabular-nums"
                />
              </div>
            </div>

            <div className="rounded-lg bg-light-surface-container-low border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-xs">
              <span className="font-title text-title-md text-light-on-surface">
                Ước tính thực nhận (ví dụ đơn 2 ngày)
              </span>
              <span className="font-body text-body-md text-light-on-surface-variant tabular-nums">
                Tiền thuê {formatVnd(dailyRate * 2)} trừ 1.000đ phí của chủ đồ ={' '}
                <strong className="text-light-primary">
                  {formatVnd(Math.max(0, dailyRate * 2 - 1000))}
                </strong>
              </span>
              <span className="font-label text-label-sm text-light-on-surface-variant tabular-nums">
                Lúc giao bạn thu của người thuê: {formatVnd(dailyRate * 2 + 1000 + deposit)} (gồm{' '}
                {formatVnd(deposit)} cọc để hoàn khi trả đồ).
              </span>
            </div>
          </section>
        )}

        {step === 3 && (
          <section className="flex flex-col gap-gutter-md">
            <div className="flex flex-col gap-gutter-xs">
              <span className="font-label text-label-lg text-light-on-surface">
                Chọn cơ sở hẹn giao tại ĐH Sài Gòn
              </span>
              <div className="grid grid-cols-3 gap-gutter-sm">
                {CAMPUSES.map((c) => (
                  <button
                    key={c}
                    type="button"
                    onClick={() => setArea(c)}
                    className={`min-h-[44px] rounded-md font-label text-label-md border ${
                      area === c
                        ? 'bg-light-secondary-container border-light-primary text-light-on-secondary-container'
                        : 'bg-light-surface-container-lowest border-light-outline-variant text-light-on-surface'
                    }`}
                  >
                    {c}
                  </button>
                ))}
              </div>
            </div>

            <div className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
              <span className="font-label text-label-sm text-light-primary">
                XEM TRƯỚC TIN ĐĂNG
              </span>
              <div className="aspect-[4/3] max-h-56 rounded-md overflow-hidden bg-light-surface-container">
                <AuthPhoto
                  photoIds={photoIds}
                  fallbackKey={editingListing?.id || 'item-1'}
                  alt="Xem trước"
                />
              </div>
              <h2 className="font-title text-title-md text-light-on-surface">
                {title || 'Chưa đặt tên món đồ'}
              </h2>
              <p className="font-label text-label-lg text-light-primary tabular-nums">
                {formatVnd(dailyRate)}/ngày · Cọc {formatVnd(deposit)} · {area}
              </p>
            </div>
          </section>
        )}
      </main>

      <footer className="fixed bottom-0 left-0 lg:left-60 right-0 z-30 bg-light-surface-container-lowest border-t border-light-outline-variant px-page-margin py-gutter-sm">
        <div className="max-w-[680px] mx-auto">
          {step < 3 ? (
            <button
              type="button"
              onClick={() => setStep((s) => (s === 1 ? 2 : 3))}
              className="w-full inline-flex items-center justify-center min-h-[48px] px-6 py-3 rounded-full bg-light-primary text-light-on-primary font-label text-label-lg"
            >
              {step === 1 ? 'Tiếp tục sang Giá & Cọc' : 'Tiếp tục chọn Cơ sở & Xem trước'}
            </button>
          ) : (
            <button
              type="button"
              disabled={busy || !title.trim()}
              onClick={handlePublish}
              className="w-full inline-flex items-center justify-center min-h-[48px] px-6 py-3 rounded-full bg-light-primary text-light-on-primary font-label text-label-lg disabled:opacity-50"
            >
              {busy
                ? 'Đang lưu tin...'
                : editingListing
                ? 'Cập nhật tin đăng'
                : 'Đăng tin cho thuê'}
            </button>
          )}
        </div>
      </footer>
    </div>
  );
}

interface MyListingsScreenProps {
  me: Me | null;
  onBack: () => void;
  onNewListing: () => void;
  onEditListing: (listing: Listing) => void;
}

export function MyListingsScreen({
  me,
  onBack,
  onNewListing,
  onEditListing,
}: MyListingsScreenProps) {
  const [myListings, setMyListings] = useState<Listing[]>([]);
  const [selectedListing, setSelectedListing] = useState<Listing | null>(null);
  const [blocks, setBlocks] = useState<Block[]>([]);
  const [blockStart, setBlockStart] = useState('2027-03-10');
  const [blockEnd, setBlockEnd] = useState('2027-03-11');
  const [conflictAlert, setConflictAlert] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const loadMine = async () => {
    if (!me) return;
    const page = await api.listListings({ mine: true });
    setMyListings(page.items);
    if (page.items[0]) {
      setSelectedListing(page.items[0]);
      const bPage = await api.listBlocks(page.items[0].id);
      setBlocks(bPage.items);
    }
  };

  useEffect(() => {
    loadMine();
  }, [me]);

  const handleSelectForSchedule = async (item: Listing) => {
    setSelectedListing(item);
    setConflictAlert(null);
    const bPage = await api.listBlocks(item.id);
    setBlocks(bPage.items);
  };

  const handleAddBlock = async () => {
    if (!selectedListing) return;
    setBusy(true);
    setConflictAlert(null);
    try {
      await api.createBlock(selectedListing.id, {
        start_date: blockStart,
        end_date: blockEnd,
      });
      const bPage = await api.listBlocks(selectedListing.id);
      setBlocks(bPage.items);
    } catch (e: any) {
      if (e instanceof ApiClientError && e.code === 'schedule_conflict') {
        setConflictAlert(
          `Khoảng ${blockStart} – ${blockEnd} đã có đơn thuê được duyệt hoặc lịch bận. Vui lòng chọn khoảng ngày khác.`,
        );
      } else {
        setConflictAlert(e?.message || 'Không thể khóa ngày bận.');
      }
    } finally {
      setBusy(false);
    }
  };

  const handleDeleteBlock = async (blockId: string) => {
    if (!selectedListing) return;
    await api.deleteBlock(selectedListing.id, blockId);
    const bPage = await api.listBlocks(selectedListing.id);
    setBlocks(bPage.items);
  };

  return (
    <div className="flex flex-col pb-24">
      <header className="sticky top-0 z-20 bg-light-surface border-b border-light-outline-variant px-gutter-sm py-gutter-xs flex items-center justify-between gap-gutter-sm">
        <div className="flex items-center gap-gutter-xs">
          <button
            type="button"
            onClick={onBack}
            className="inline-flex items-center justify-center w-12 h-12 rounded-full text-light-on-surface hover:bg-light-surface-container"
          >
            <span className="material-symbols-outlined text-[24px]">arrow_back</span>
          </button>
          <h1 className="font-title text-title-lg text-light-on-surface">
            S06 · Tin của tôi & Lịch
          </h1>
        </div>
        <button
          type="button"
          onClick={onNewListing}
          className="px-3 py-2 rounded-full bg-light-primary text-light-on-primary font-label text-label-md"
        >
          + Đăng mới
        </button>
      </header>

      <main className="flex-1 flex flex-col gap-gutter-md px-page-margin pt-gutter-md">
        {myListings.length === 0 ? (
          <div className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-lg text-center font-body text-body-md text-light-on-surface-variant">
            Bạn chưa đăng món đồ nào. Bấm &ldquo;+ Đăng mới&rdquo; ở góc trên để tạo tin đầu tiên.
          </div>
        ) : (
          myListings.map((item) => (
            <article
              key={item.id}
              className={`rounded-lg bg-light-surface-container-lowest border p-gutter-md flex flex-col gap-gutter-sm ${
                selectedListing?.id === item.id
                  ? 'border-light-primary'
                  : 'border-light-outline-variant'
              }`}
            >
              <div className="flex gap-gutter-sm">
                <div className="w-24 aspect-[4/3] rounded-md overflow-hidden shrink-0 bg-light-surface-container">
                  <AuthPhoto
                    photoIds={item.photo_ids}
                    fallbackKey={item.id}
                    alt={item.title}
                  />
                </div>
                <div className="flex-1 flex flex-col justify-between gap-1">
                  <h2 className="font-title text-title-md text-light-on-surface">
                    {item.title}
                  </h2>
                  <p className="font-label text-label-lg text-light-primary tabular-nums">
                    {formatVnd(item.daily_rate)}/ngày · Cọc {formatVnd(item.deposit)}
                  </p>
                  <span className="font-label text-label-sm text-light-on-surface-variant">
                    {item.area} · Phiên bản #{item.revision}
                  </span>
                </div>
              </div>

              <div className="flex flex-wrap gap-gutter-sm pt-gutter-xs border-t border-light-outline-variant">
                <button
                  type="button"
                  onClick={() => onEditListing(item)}
                  className="inline-flex items-center justify-center min-h-[40px] px-4 py-2 rounded-full bg-light-secondary-container text-light-on-secondary-container font-label text-label-md"
                >
                  Sửa tin
                </button>
                <button
                  type="button"
                  onClick={() => handleSelectForSchedule(item)}
                  className="inline-flex items-center justify-center min-h-[40px] px-4 py-2 rounded-full border border-light-outline-variant bg-light-surface-container-lowest text-light-on-surface font-label text-label-md"
                >
                  Quản lý lịch bận
                </button>
              </div>
            </article>
          ))
        )}

        {conflictAlert && (
          <div
            role="alert"
            className="rounded-lg bg-light-error-container text-light-on-error-container p-gutter-md flex items-start gap-gutter-sm"
          >
            <span className="material-symbols-outlined text-[20px] mt-0.5 shrink-0">
              event_busy
            </span>
            <div className="flex flex-col gap-1">
              <span className="font-label text-label-lg">
                Xung đột lịch với đơn đã duyệt
              </span>
              <p className="font-body text-body-md tabular-nums">{conflictAlert}</p>
            </div>
          </div>
        )}

        {selectedListing && (
          <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
            <h3 className="font-title text-title-md text-light-on-surface">
              Khóa ngày bận cho: {selectedListing.title}
            </h3>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-gutter-sm items-end">
              <div className="flex flex-col gap-1">
                <label className="font-label text-label-sm text-light-on-surface-variant">
                  Từ ngày
                </label>
                <input
                  type="date"
                  value={blockStart}
                  onChange={(e) => setBlockStart(e.target.value)}
                  className="min-h-[44px] px-3 rounded-md border border-light-outline-variant font-mono text-body-md"
                />
              </div>
              <div className="flex flex-col gap-1">
                <label className="font-label text-label-sm text-light-on-surface-variant">
                  Đến ngày
                </label>
                <input
                  type="date"
                  value={blockEnd}
                  min={blockStart}
                  onChange={(e) => setBlockEnd(e.target.value)}
                  className="min-h-[44px] px-3 rounded-md border border-light-outline-variant font-mono text-body-md"
                />
              </div>
              <button
                type="button"
                disabled={busy}
                onClick={handleAddBlock}
                className="min-h-[44px] px-4 rounded-full bg-light-primary text-light-on-primary font-label text-label-md"
              >
                Khóa khoảng ngày này
              </button>
            </div>

            <div className="pt-gutter-sm border-t border-light-outline-variant flex flex-col gap-gutter-xs">
              <span className="font-label text-label-md text-light-on-surface">
                Khoảng ngày bạn đang tự khóa
              </span>
              {blocks.length === 0 ? (
                <span className="font-body text-body-md text-light-on-surface-variant">
                  Chưa có khoảng ngày tự khóa nào.
                </span>
              ) : (
                blocks.map((b) => (
                  <div
                    key={b.id}
                    className="flex items-center justify-between gap-gutter-sm py-gutter-xs border-b border-light-outline-variant last:border-b-0"
                  >
                    <div className="flex flex-col">
                      <span className="font-label text-label-md text-light-on-surface tabular-nums">
                        {b.start_date} – {b.end_date}
                      </span>
                      <span className="font-body text-body-md text-light-on-surface-variant">
                        Tự khóa bởi chủ đồ
                      </span>
                    </div>
                    <button
                      type="button"
                      onClick={() => handleDeleteBlock(b.id)}
                      className="px-3 py-1.5 rounded-full border border-light-outline-variant font-label text-label-sm text-light-primary"
                    >
                      Mở lại
                    </button>
                  </div>
                ))
              )}
            </div>
          </section>
        )}

        <div className="rounded-md bg-light-surface-container-low p-gutter-sm flex items-start gap-gutter-sm">
          <span className="material-symbols-outlined text-[18px] text-light-primary mt-0.5 shrink-0">
            info
          </span>
          <p className="font-body text-body-md text-light-on-surface-variant">
            Đơn cũ vẫn giữ nguyên giá thuê, tiền cọc và danh sách phụ kiện đã chốt ngay cả khi bạn cập nhật tin.
          </p>
        </div>
      </main>
    </div>
  );
}
