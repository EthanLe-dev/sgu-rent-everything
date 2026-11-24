'use client';

import React, { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import {
  computeHandoverPin,
  describeOrderState,
  formatShortDateRange,
  formatTimeVN,
  formatVnd,
  SAFE_PICKUP_SPOTS,
} from '@/lib/format';
import type { Me, Message, Order } from '@/lib/types';
import { AuthPhoto } from './AuthPhoto';

interface OrdersListScreenProps {
  me: Me | null;
  onSelectOrder: (orderId: string) => void;
  onOpenNotifications: () => void;
  unreadCount: number;
  onRequireLogin: () => void;
}

export function OrdersListScreen({
  me,
  onSelectOrder,
  onOpenNotifications,
  unreadCount,
  onRequireLogin,
}: OrdersListScreenProps) {
  const [roleView, setRoleView] = useState<'renter' | 'owner'>('renter');
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadOrders = async (role = roleView, status = statusFilter) => {
    if (!me) return;
    setLoading(true);
    setError(null);
    try {
      const page = await api.listOrders(role, status || undefined);
      setOrders(page.items);
    } catch (e: any) {
      setError(e?.message || 'Không thể tải danh sách giao dịch.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (me) loadOrders();
  }, [me, roleView, statusFilter]);

  if (!me) {
    return (
      <div className="p-gutter-md flex flex-col gap-gutter-md">
        <div className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-lg flex flex-col items-center text-center gap-gutter-sm">
          <span className="material-symbols-outlined text-[32px] text-light-primary">
            swap_horiz
          </span>
          <h2 className="font-title text-title-lg text-light-on-surface">
            Đăng nhập để xem giao dịch
          </h2>
          <p className="font-body text-body-md text-light-on-surface-variant">
            Theo dõi các đơn bạn đang đi thuê và đang cho thuê, biên nhận bàn giao và tiền cọc.
          </p>
          <button
            type="button"
            onClick={onRequireLogin}
            className="min-h-[48px] px-6 rounded-full bg-light-primary text-light-on-primary font-label text-label-lg"
          >
            Đăng nhập ngay
          </button>
        </div>
      </div>
    );
  }

  const overdueOrders = orders.filter((o) => o.overdue);

  return (
    <div className="flex flex-col pb-24">
      <header className="sticky top-0 z-20 bg-light-surface border-b border-light-outline-variant px-page-margin py-gutter-sm flex items-center justify-between gap-gutter-sm">
        <h1 className="font-title text-title-lg text-light-on-surface">S07 · Giao dịch</h1>
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
      </header>

      <div className="flex flex-col gap-gutter-md px-page-margin pt-gutter-md">
        {/* Role Switcher */}
        <div
          className="grid grid-cols-2 gap-gutter-xs p-1 rounded-full bg-light-surface-container border border-light-outline-variant"
          role="tablist"
        >
          <button
            type="button"
            onClick={() => setRoleView('renter')}
            className={`min-h-[40px] rounded-full font-label text-label-md transition-colors ${
              roleView === 'renter'
                ? 'bg-light-surface-container-lowest text-light-primary shadow-sm'
                : 'text-light-on-surface-variant'
            }`}
          >
            Tôi đi thuê
          </button>
          <button
            type="button"
            onClick={() => setRoleView('owner')}
            className={`min-h-[40px] rounded-full font-label text-label-md transition-colors ${
              roleView === 'owner'
                ? 'bg-light-surface-container-lowest text-light-primary shadow-sm'
                : 'text-light-on-surface-variant'
            }`}
          >
            Tôi cho thuê
          </button>
        </div>

        {/* Status Filter Chips */}
        <div className="flex items-center gap-gutter-xs overflow-x-auto pb-1">
          {[
            { value: '', label: 'Tất cả' },
            { value: 'requested', label: 'Chờ duyệt' },
            { value: 'approved', label: 'Chờ giao' },
            { value: 'active', label: 'Đang thuê' },
            { value: 'returned', label: 'Chờ cọc' },
            { value: 'completed', label: 'Hoàn tất' },
          ].map((chip) => (
            <button
              key={chip.value}
              type="button"
              onClick={() => setStatusFilter(chip.value)}
              className={`shrink-0 min-h-[36px] px-3.5 rounded-full font-label text-label-md ${
                statusFilter === chip.value
                  ? 'bg-light-secondary-container text-light-on-secondary-container'
                  : 'bg-light-surface-container-lowest border border-light-outline-variant text-light-on-surface-variant'
              }`}
            >
              {chip.label}
            </button>
          ))}
        </div>

        {/* Overdue Alert Banner */}
        {overdueOrders.map((od) => (
          <div
            key={od.id}
            role="alert"
            className="rounded-lg bg-light-error-container text-light-on-error-container p-gutter-md flex items-start gap-gutter-sm"
          >
            <span className="material-symbols-outlined text-[20px] mt-0.5 shrink-0">warning</span>
            <div className="flex flex-col gap-0.5">
              <span className="font-label text-label-lg">
                Đơn #{od.id} đang giữ món quá hạn (hạn trả {od.quote.end_date})
              </span>
              <span className="font-body text-body-md">
                Người giữ: {od.renter.display_name}. Lượt bàn giao kế tiếp sẽ bị chặn cho đến khi thu hồi xong món đồ.
              </span>
            </div>
          </div>
        ))}

        {error && (
          <div className="rounded-lg bg-light-error-container text-light-on-error-container p-gutter-md flex items-center justify-between">
            <span className="font-body text-body-md">{error}</span>
            <button
              type="button"
              onClick={() => loadOrders()}
              className="px-3 py-1.5 rounded-full bg-light-surface-container-lowest text-light-on-surface font-label text-label-sm"
            >
              Thử lại
            </button>
          </div>
        )}

        {loading ? (
          <div className="py-12 text-center font-body text-body-md text-light-on-surface-variant">
            Đang tải danh sách đơn...
          </div>
        ) : orders.length === 0 ? (
          <div className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-lg flex flex-col items-center text-center gap-gutter-xs">
            <span className="material-symbols-outlined text-[28px] text-light-on-surface-variant">
              inbox
            </span>
            <span className="font-title text-title-md text-light-on-surface">
              Chưa có yêu cầu thuê
            </span>
            <span className="font-body text-body-md text-light-on-surface-variant">
              {roleView === 'renter'
                ? 'Bạn chưa gửi yêu cầu thuê nào ở bộ lọc này.'
                : 'Chưa có sinh viên nào đặt thuê món đồ của bạn ở bộ lọc này.'}
            </span>
          </div>
        ) : (
          <section className="grid grid-cols-1 md:grid-cols-2 gap-gutter-sm">
            {orders.map((order) => {
              const info = describeOrderState(order, me.id);
              const badgeClass =
                info.tone === 'success'
                  ? 'bg-success-container text-on-success-container'
                  : info.tone === 'warning'
                  ? 'bg-warning-container text-on-warning-container'
                  : info.tone === 'error'
                  ? 'bg-light-error-container text-light-on-error-container'
                  : 'bg-light-secondary-container text-light-on-secondary-container';

              return (
                <button
                  key={order.id}
                  type="button"
                  onClick={() => onSelectOrder(order.id)}
                  className="text-left rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm hover:border-light-primary transition-colors"
                >
                  <div className="flex items-center justify-between gap-gutter-sm">
                    <span
                      className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full font-label text-label-sm ${badgeClass}`}
                    >
                      <span className="material-symbols-outlined text-[14px]">{info.icon}</span>
                      {info.badgeLabel}
                    </span>
                    <span className="font-mono text-mono-sm text-light-on-surface-variant tabular-nums">
                      #{order.id}
                    </span>
                  </div>

                  <div className="flex gap-gutter-sm items-center">
                    <div className="w-16 aspect-[4/3] rounded-md overflow-hidden shrink-0 bg-light-surface-container">
                      <AuthPhoto fallbackKey={order.listing_id} alt={order.title} />
                    </div>
                    <div className="flex-1 flex flex-col gap-0.5 min-w-0">
                      <h2 className="font-title text-title-md text-light-on-surface truncate">
                        {order.title}
                      </h2>
                      <span className="font-body text-body-md text-light-on-surface-variant">
                        {roleView === 'renter'
                          ? `Chủ đồ: ${order.owner.display_name} · ${order.pickup_point}`
                          : `Người thuê: ${order.renter.display_name} · ${order.pickup_point}`}
                      </span>
                      <span className="font-label text-label-sm text-light-primary tabular-nums">
                        {formatShortDateRange(order.quote.start_date, order.quote.end_date)} ·{' '}
                        {roleView === 'renter'
                          ? `Mang ${formatVnd(order.quote.pickup_total)}`
                          : `Thu ${formatVnd(order.quote.pickup_total)} · Thực nhận ${formatVnd(
                              order.quote.owner_net,
                            )}`}
                      </span>
                    </div>
                  </div>

                  <div className="pt-gutter-xs border-t border-light-outline-variant flex items-center justify-between gap-2">
                    <span className="font-label text-label-md text-light-primary truncate">
                      Việc tiếp theo: {info.nextStep}
                    </span>
                    <span className="material-symbols-outlined text-[20px] text-light-primary shrink-0">
                      chevron_right
                    </span>
                  </div>
                </button>
              );
            })}
          </section>
        )}
      </div>
    </div>
  );
}

interface OrderDetailScreenProps {
  orderId: string;
  me: Me | null;
  onBack: () => void;
  onOpenReport: (orderId: string, defaultCategory?: string) => void;
}

export function OrderDetailScreen({
  orderId,
  me,
  onBack,
  onOpenReport,
}: OrderDetailScreenProps) {
  const [order, setOrder] = useState<Order | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  const [notFoundOrForbidden, setNotFoundOrForbidden] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // Sub-views: 'detail' | 's09' (Handover receipt) | 's10' (Deposit result)
  const [subView, setSubView] = useState<'detail' | 's09' | 's10'>('detail');

  // Chat state (retains input on network error for retry)
  const [chatText, setChatText] = useState('');
  const [failedChatText, setFailedChatText] = useState<string | null>(null);

  // Reject / Cancel reason modal
  const [reasonModal, setReasonModal] = useState<'reject' | 'cancel' | null>(null);
  const [reasonInput, setReasonInput] = useState('Bận lịch học đột xuất');

  // S09 Handover Receipt form state
  const [handoffCondition, setHandoffCondition] = useState(
    'Đúng mô tả · Rất tốt, không trầy xước',
  );
  const [handoffAccChecked, setHandoffAccChecked] = useState(true);
  const [handoffPhotoIds, setHandoffPhotoIds] = useState<string[]>([]);
  const [uploadingPhoto, setUploadingPhoto] = useState(false);

  // S10 Deposit form state
  const [refundAmountInput, setRefundAmountInput] = useState('0');
  const [refundReasonInput, setRefundReasonInput] = useState('');

  const loadAll = async () => {
    setLoading(true);
    setNotFoundOrForbidden(false);
    setActionError(null);
    try {
      const [o, msgPage] = await Promise.all([
        api.getOrder(orderId),
        api.listMessages(orderId),
      ]);
      setOrder(o);
      setMessages(msgPage.items);
      setRefundAmountInput(String(o.quote.deposit));
    } catch (e: any) {
      if (e?.status === 404 || e?.status === 403) {
        setNotFoundOrForbidden(true);
      } else {
        setActionError(e?.message || 'Không thể tải thông tin đơn thuê.');
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadAll();
  }, [orderId]);

  if (loading) {
    return (
      <div className="p-gutter-lg text-center font-body text-body-md text-light-on-surface-variant">
        Đang tải chi tiết đơn #{orderId}...
      </div>
    );
  }

  if (notFoundOrForbidden || !order) {
    return (
      <div className="p-gutter-lg flex flex-col items-center text-center gap-gutter-md">
        <span className="material-symbols-outlined text-[36px] text-light-error">lock</span>
        <h2 className="font-title text-title-lg text-light-on-surface">
          Không tìm thấy đơn hoặc bạn không có quyền xem
        </h2>
        <p className="font-body text-body-md text-light-on-surface-variant">
          Đơn thuê, tin nhắn và ảnh bàn giao chỉ hiển thị cho người thuê, chủ đồ hoặc quản trị viên xử lý vụ việc.
        </p>
        <button
          type="button"
          onClick={onBack}
          className="min-h-[48px] px-6 rounded-full bg-light-primary text-light-on-primary font-label text-label-lg"
        >
          Quay về danh sách
        </button>
      </div>
    );
  }

  const isOwner = me?.id === order.owner.id;
  const info = describeOrderState(order, me?.id);
  const handoverPin = computeHandoverPin(order.id);
  const safeSpots = SAFE_PICKUP_SPOTS[order.pickup_point] || SAFE_PICKUP_SPOTS['Cơ sở Chính'];

  const handleApprove = async () => {
    setBusy(true);
    setActionError(null);
    try {
      const updated = await api.approveOrder(order.id);
      setOrder(updated);
    } catch (e: any) {
      setActionError(e?.message || 'Không thể duyệt đơn.');
      await loadAll();
    } finally {
      setBusy(false);
    }
  };

  const handleRejectOrCancel = async () => {
    if (!reasonModal || !reasonInput.trim()) return;
    setBusy(true);
    setActionError(null);
    try {
      const updated =
        reasonModal === 'reject'
          ? await api.rejectOrder(order.id, reasonInput.trim())
          : await api.cancelOrder(order.id, reasonInput.trim());
      setOrder(updated);
      setReasonModal(null);
    } catch (e: any) {
      setActionError(e?.message || 'Thao tác không thành công.');
      await loadAll();
    } finally {
      setBusy(false);
    }
  };

  const handleUploadHandoffPhoto = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadingPhoto(true);
    setActionError(null);
    try {
      const uploaded = await api.uploadPhoto(file, 'handover', order.id);
      setHandoffPhotoIds((prev) => [...prev, uploaded.id]);
    } catch (err: any) {
      setActionError(err?.message || 'Lỗi tải ảnh bàn giao (chỉ nhận JPEG/PNG tối đa 8 MiB).');
    } finally {
      setUploadingPhoto(false);
    }
  };

  const handleSubmitHandoffReceipt = async () => {
    setBusy(true);
    setActionError(null);
    try {
      const acc = handoffAccChecked ? order.accessories : [];
      const updated =
        order.status === 'approved'
          ? await api.pickupOrder(order.id, {
              condition: handoffCondition.trim(),
              accessories: acc,
              photo_ids: handoffPhotoIds,
              cash_received: order.quote.pickup_total,
            })
          : await api.returnOrder(order.id, {
              condition: handoffCondition.trim(),
              accessories: acc,
              photo_ids: handoffPhotoIds,
            });
      setOrder(updated);
      setSubView('detail');
    } catch (e: any) {
      setActionError(e?.message || 'Không thể lưu biên nhận bàn giao.');
      await loadAll();
    } finally {
      setBusy(false);
    }
  };

  const handleSubmitDeposit = async () => {
    setBusy(true);
    setActionError(null);
    try {
      const refunded = Number(refundAmountInput.replace(/\D/g, '')) || 0;
      const updated = await api.depositOrder(order.id, {
        refunded,
        reason: refunded < order.quote.deposit ? refundReasonInput.trim() : undefined,
      });
      setOrder(updated);
      setSubView('detail');
    } catch (e: any) {
      setActionError(e?.message || 'Không thể lưu kết quả tiền cọc.');
      await loadAll();
    } finally {
      setBusy(false);
    }
  };

  const handleSendChat = async (textToSend = chatText) => {
    const trimmed = textToSend.trim();
    if (!trimmed) return;
    setActionError(null);
    try {
      const msg = await api.sendMessage(order.id, trimmed);
      setMessages((prev) => [...prev, msg]);
      setChatText('');
      setFailedChatText(null);
    } catch {
      setFailedChatText(trimmed);
    }
  };

  // Sub-view S09: Biên nhận giao và trả
  if (subView === 's09') {
    const isPickup = order.status === 'approved';
    const receipts = isPickup ? order.pickup : order.returned;
    const ownerReceipt = receipts.find((r) => r.actor_id === order.owner.id);
    const renterReceipt = receipts.find((r) => r.actor_id === order.renter.id);
    const myReceipt = receipts.find((r) => r.actor_id === me?.id);

    return (
      <div className="flex flex-col pb-28">
        <header className="sticky top-0 z-20 bg-light-surface border-b border-light-outline-variant px-gutter-sm py-gutter-xs flex items-center gap-gutter-xs">
          <button
            type="button"
            onClick={() => setSubView('detail')}
            className="inline-flex items-center justify-center w-12 h-12 rounded-full text-light-on-surface hover:bg-light-surface-container"
          >
            <span className="material-symbols-outlined text-[24px]">arrow_back</span>
          </button>
          <div className="flex flex-col">
            <h1 className="font-title text-title-md text-light-on-surface">
              S09 · Biên nhận giao và trả
            </h1>
            <span className="font-label text-label-sm text-light-on-surface-variant">
              Đơn #{order.id} · {order.title}
            </span>
          </div>
        </header>

        <main className="flex-1 flex flex-col gap-gutter-md px-page-margin pt-gutter-md">
          {/* Handover PIN verification card (Trust & Safety) */}
          <section className="rounded-lg bg-light-secondary-container text-light-on-secondary-container p-gutter-md flex items-center justify-between gap-gutter-sm">
            <div className="flex flex-col gap-0.5">
              <span className="font-label text-label-md">
                Mã đối chiếu gặp mặt trực tiếp (PIN)
              </span>
              <span className="font-body text-body-md">
                Hai bên đọc khớp 4 số này tại {order.pickup_point} trước khi bấm ký biên nhận.
              </span>
            </div>
            <span className="px-3 py-1.5 rounded-md bg-light-surface-container-lowest text-light-primary font-mono text-title-lg tracking-widest tabular-nums">
              {handoverPin}
            </span>
          </section>

          {/* Two-party Confirmation Status */}
          <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
            <h2 className="font-title text-title-md text-light-on-surface">
              {isPickup
                ? `Lượt giao đồ (${order.quote.start_date})`
                : `Lượt trả đồ (${order.quote.end_date})`}
            </h2>

            <div className="flex items-center justify-between gap-gutter-sm py-gutter-xs border-b border-light-outline-variant">
              <div className="flex items-center gap-gutter-sm">
                <span
                  className={`material-symbols-outlined text-[20px] ${
                    ownerReceipt ? 'text-success material-fill' : 'text-warning'
                  }`}
                >
                  {ownerReceipt ? 'check_circle' : 'schedule'}
                </span>
                <div className="flex flex-col">
                  <span className="font-label text-label-md text-light-on-surface">
                    {order.owner.display_name} (chủ đồ)
                  </span>
                  <span className="font-label text-label-sm text-light-on-surface-variant tabular-nums">
                    {ownerReceipt
                      ? `${formatTimeVN(ownerReceipt.confirmed_at)} · ${ownerReceipt.condition}`
                      : 'Đang chờ tự xác nhận phần mình'}
                  </span>
                </div>
              </div>
              <span
                className={`px-2.5 py-0.5 rounded-full font-label text-label-sm ${
                  ownerReceipt
                    ? 'bg-success-container text-on-success-container'
                    : 'bg-warning-container text-on-warning-container'
                }`}
              >
                {ownerReceipt ? 'Đã ký' : 'Chờ xác nhận'}
              </span>
            </div>

            <div className="flex items-center justify-between gap-gutter-sm py-gutter-xs">
              <div className="flex items-center gap-gutter-sm">
                <span
                  className={`material-symbols-outlined text-[20px] ${
                    renterReceipt ? 'text-success material-fill' : 'text-warning'
                  }`}
                >
                  {renterReceipt ? 'check_circle' : 'schedule'}
                </span>
                <div className="flex flex-col">
                  <span className="font-label text-label-md text-light-on-surface">
                    {order.renter.display_name} (người thuê)
                  </span>
                  <span className="font-label text-label-sm text-light-on-surface-variant tabular-nums">
                    {renterReceipt
                      ? `${formatTimeVN(renterReceipt.confirmed_at)} · ${renterReceipt.condition}`
                      : 'Đang chờ tự xác nhận phần mình'}
                  </span>
                </div>
              </div>
              <span
                className={`px-2.5 py-0.5 rounded-full font-label text-label-sm ${
                  renterReceipt
                    ? 'bg-success-container text-on-success-container'
                    : 'bg-warning-container text-on-warning-container'
                }`}
              >
                {renterReceipt ? 'Đã ký' : 'Chờ xác nhận'}
              </span>
            </div>
          </section>

          {actionError && (
            <div
              role="alert"
              className="rounded-md bg-light-error-container text-light-on-error-container p-gutter-sm font-body text-body-md"
            >
              {actionError}
            </div>
          )}

          {/* Self-Confirmation Form */}
          {!myReceipt && (order.status === 'approved' || order.status === 'active') && (
            <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
              <h3 className="font-title text-title-md text-light-on-surface">
                Ghi nhận phần của {me?.display_name}
              </h3>

              <div className="flex flex-col gap-1">
                <label className="font-label text-label-md text-light-on-surface">
                  Tình trạng món đồ khi {isPickup ? 'nhận/giao' : 'trả'}
                </label>
                <input
                  type="text"
                  value={handoffCondition}
                  onChange={(e) => setHandoffCondition(e.target.value)}
                  className="w-full min-h-[44px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md text-light-on-surface"
                />
              </div>

              <div className="flex flex-col gap-1">
                <span className="font-label text-label-md text-light-on-surface">
                  Kiểm tra phụ kiện kèm theo
                </span>
                <label className="flex items-center gap-gutter-sm min-h-[40px] px-3 rounded-md bg-light-surface-container-low cursor-pointer">
                  <input
                    type="checkbox"
                    checked={handoffAccChecked}
                    onChange={(e) => setHandoffAccChecked(e.target.checked)}
                    className="rounded text-light-primary"
                  />
                  <span className="font-body text-body-md text-light-on-surface">
                    Đủ phụ kiện: {order.accessories.join(', ') || 'Không có phụ kiện lẻ'}
                  </span>
                </label>
              </div>

              {isPickup && (
                <div className="flex items-center justify-between rounded-md bg-light-surface-container-low p-gutter-sm">
                  <span className="font-body text-body-md text-light-on-surface-variant">
                    Số tiền thực trao lúc giao (tiền thuê + 1.000đ phí + cọc)
                  </span>
                  <span className="font-title text-title-md text-light-primary tabular-nums">
                    {formatVnd(order.quote.pickup_total)}
                  </span>
                </div>
              )}

              <div className="flex flex-col gap-1">
                <span className="font-label text-label-md text-light-on-surface">
                  Ảnh bàn giao thực tế{' '}
                  {order.quote.deposit > 0
                    ? '(Khuyến nghị chụp tối thiểu 1 ảnh vì đơn có tiền cọc)'
                    : '(tùy chọn)'}
                </span>
                <label className="min-h-[44px] rounded-md border border-dashed border-light-outline-variant bg-light-surface-container-low flex items-center justify-center gap-gutter-xs text-light-primary font-label text-label-md cursor-pointer hover:bg-light-surface-container">
                  <span className="material-symbols-outlined text-[20px]">add_a_photo</span>
                  <span>
                    {uploadingPhoto
                      ? 'Đang tải ảnh lên...'
                      : `Chụp / Chọn ảnh bàn giao (${handoffPhotoIds.length} ảnh)`}
                  </span>
                  <input
                    type="file"
                    accept="image/jpeg,image/png"
                    capture="environment"
                    onChange={handleUploadHandoffPhoto}
                    className="hidden"
                  />
                </label>
              </div>
            </section>
          )}
        </main>

        {!myReceipt && (order.status === 'approved' || order.status === 'active') && (
          <footer className="fixed bottom-0 left-0 lg:left-60 right-0 z-30 bg-light-surface-container-lowest border-t border-light-outline-variant px-page-margin py-gutter-sm">
            <div className="max-w-[680px] mx-auto">
              <button
                type="button"
                disabled={busy}
                onClick={handleSubmitHandoffReceipt}
                className="w-full inline-flex items-center justify-center min-h-[48px] px-6 py-3 rounded-full bg-light-primary text-light-on-primary hover:bg-light-primary-container font-label text-label-lg disabled:opacity-50"
              >
                {isPickup
                  ? isOwner
                    ? `Xác nhận đã giao đồ & thu ${formatVnd(order.quote.pickup_total)}`
                    : `Xác nhận đã nhận đồ & trao ${formatVnd(order.quote.pickup_total)}`
                  : isOwner
                  ? 'Xác nhận đã nhận lại đồ'
                  : 'Xác nhận đã trả đồ'}
              </button>
            </div>
          </footer>
        )}
      </div>
    );
  }

  // Sub-view S10: Kết quả tiền cọc
  if (subView === 's10') {
    const refundedNum = Number(refundAmountInput.replace(/\D/g, '')) || 0;
    const isPartial = refundedNum < order.quote.deposit;
    const myClaim = order.deposit_result.claims.find((c) => c.actor_id === me?.id);
    const ownerClaim = order.deposit_result.claims.find((c) => c.actor_id === order.owner.id);
    const renterClaim = order.deposit_result.claims.find((c) => c.actor_id === order.renter.id);

    return (
      <div className="flex flex-col pb-28">
        <header className="sticky top-0 z-20 bg-light-surface border-b border-light-outline-variant px-gutter-sm py-gutter-xs flex items-center gap-gutter-xs">
          <button
            type="button"
            onClick={() => setSubView('detail')}
            className="inline-flex items-center justify-center w-12 h-12 rounded-full text-light-on-surface hover:bg-light-surface-container"
          >
            <span className="material-symbols-outlined text-[24px]">arrow_back</span>
          </button>
          <div className="flex flex-col">
            <h1 className="font-title text-title-md text-light-on-surface">
              S10 · Kết quả tiền cọc
            </h1>
            <span className="font-label text-label-sm text-light-on-surface-variant">
              Đơn #{order.id} · {order.title}
            </span>
          </div>
        </header>

        <main className="flex-1 flex flex-col gap-gutter-md px-page-margin pt-gutter-md">
          <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
            <div className="flex items-center justify-between gap-gutter-sm">
              <span className="font-title text-title-md text-light-on-surface">Mức cọc đã giữ</span>
              <span className="font-headline text-headline-md text-light-primary tabular-nums">
                {formatVnd(order.quote.deposit)}
              </span>
            </div>
            <p className="font-body text-body-md text-light-on-surface-variant">
              Mỗi bên tự nhập số tiền cọc đã hoàn từ 0đ đến {formatVnd(order.quote.deposit)}. Nếu hai số khớp, đơn hoàn tất ngay. Nếu lệch nhau, hệ thống tự mở vụ việc để Quản trị viên phân xử dựa trên biên nhận giao/trả.
            </p>
          </section>

          <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
            <div className="flex items-center justify-between gap-gutter-sm">
              <h2 className="font-title text-title-md text-light-on-surface">
                Trạng thái đối chiếu
              </h2>
              <span
                className={`px-2.5 py-0.5 rounded-full font-label text-label-sm ${
                  order.deposit_result.status === 'agreed' ||
                  order.deposit_result.status === 'resolved'
                    ? 'bg-success-container text-on-success-container'
                    : order.deposit_result.status === 'disputed'
                    ? 'bg-light-error-container text-light-on-error-container'
                    : 'bg-warning-container text-on-warning-container'
                }`}
              >
                {order.deposit_result.status === 'agreed'
                  ? 'Đã thống nhất'
                  : order.deposit_result.status === 'resolved'
                  ? 'QTV đã phân xử'
                  : order.deposit_result.status === 'disputed'
                  ? 'Đang tranh chấp'
                  : 'Chờ đối phương'}
              </span>
            </div>

            <div className="grid grid-cols-2 gap-gutter-sm pt-gutter-xs">
              <div className="rounded-md bg-light-surface-container-low p-gutter-sm flex flex-col gap-1">
                <span className="font-label text-label-sm text-light-on-surface-variant">
                  {order.owner.display_name} (chủ đồ) khai
                </span>
                <span className="font-title text-title-md text-light-on-surface tabular-nums">
                  {ownerClaim ? formatVnd(ownerClaim.refunded) : 'Chưa khai'}
                </span>
              </div>
              <div className="rounded-md bg-light-surface-container-low p-gutter-sm flex flex-col gap-1">
                <span className="font-label text-label-sm text-light-on-surface-variant">
                  {order.renter.display_name} (người thuê) khai
                </span>
                <span className="font-title text-title-md text-light-on-surface tabular-nums">
                  {renterClaim ? formatVnd(renterClaim.refunded) : 'Chưa khai'}
                </span>
              </div>
            </div>
          </section>

          {actionError && (
            <div
              role="alert"
              className="rounded-md bg-light-error-container text-light-on-error-container p-gutter-sm font-body text-body-md"
            >
              {actionError}
            </div>
          )}

          {order.status === 'returned' && !myClaim && (
            <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
              <label className="font-label text-label-lg text-light-on-surface">
                Số tiền cọc đã hoàn lại (đ)
              </label>
              <input
                type="number"
                min={0}
                max={order.quote.deposit}
                value={refundAmountInput}
                onChange={(e) => setRefundAmountInput(e.target.value)}
                className="w-full min-h-[48px] px-4 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-title text-title-lg text-light-primary tabular-nums"
              />

              {isPartial && (
                <div className="flex flex-col gap-1">
                  <label className="font-label text-label-md text-light-error">
                    Lý do hoàn thiếu (bắt buộc khi khấu trừ)
                  </label>
                  <textarea
                    rows={2}
                    value={refundReasonInput}
                    onChange={(e) => setRefundReasonInput(e.target.value)}
                    placeholder="Ví dụ: Trừ 50.000đ phí làm mất nắp ống kính."
                    className="w-full p-3 rounded-md bg-light-surface-container-lowest border border-light-error font-body text-body-md text-light-on-surface"
                  />
                </div>
              )}

              <div className="rounded-md bg-success-container text-on-success-container p-gutter-sm flex items-center justify-between">
                <span className="font-label text-label-md">
                  Chi phí thuê thực tế của {order.renter.display_name}
                </span>
                <span className="font-title text-title-md tabular-nums">
                  {formatVnd(order.quote.pickup_total - refundedNum)}
                </span>
              </div>
            </section>
          )}
        </main>

        {order.status === 'returned' && !myClaim && (
          <footer className="fixed bottom-0 left-0 lg:left-60 right-0 z-30 bg-light-surface-container-lowest border-t border-light-outline-variant px-page-margin py-gutter-sm">
            <div className="max-w-[680px] mx-auto">
              <button
                type="button"
                disabled={busy}
                onClick={handleSubmitDeposit}
                className="w-full inline-flex items-center justify-center min-h-[48px] px-6 py-3 rounded-full bg-light-primary text-light-on-primary hover:bg-light-primary-container font-label text-label-lg disabled:opacity-50"
              >
                Xác nhận mức hoàn cọc {formatVnd(refundedNum)}
              </button>
            </div>
          </footer>
        )}
      </div>
    );
  }

  // Main S08: Chi tiết đơn
  const canApprove = order.allowed_actions.includes('approve');
  const canReject = order.allowed_actions.includes('reject');
  const canCancel = order.allowed_actions.includes('cancel');
  const canPickup = order.allowed_actions.includes('pickup');
  const canReturn = order.allowed_actions.includes('return');
  const canDeposit = order.allowed_actions.includes('deposit');
  const oneSidedPickup = order.status === 'approved' && order.pickup.length === 1;

  return (
    <div className="flex flex-col pb-28">
      <header className="sticky top-0 z-20 bg-light-surface border-b border-light-outline-variant px-gutter-sm py-gutter-xs flex items-center justify-between gap-gutter-sm">
        <div className="flex items-center gap-gutter-xs">
          <button
            type="button"
            onClick={onBack}
            aria-label="Quay lại Giao dịch"
            className="inline-flex items-center justify-center w-12 h-12 rounded-full text-light-on-surface hover:bg-light-surface-container"
          >
            <span className="material-symbols-outlined text-[24px]">arrow_back</span>
          </button>
          <div className="flex flex-col">
            <h1 className="font-title text-title-md text-light-on-surface">
              S08 · Chi tiết đơn #{order.id}
            </h1>
            <span className="font-label text-label-sm text-light-on-surface-variant">
              {order.renter.display_name} (thuê) · {order.owner.display_name} (chủ đồ)
            </span>
          </div>
        </div>
        <button
          type="button"
          onClick={() => onOpenReport(order.id, oneSidedPickup ? 'handover' : 'other')}
          aria-label="Báo sự cố"
          className="inline-flex items-center justify-center w-12 h-12 rounded-full text-light-on-surface hover:bg-light-surface-container"
        >
          <span className="material-symbols-outlined text-[22px]">report_problem</span>
        </button>
      </header>

      <main className="flex-1 flex flex-col gap-gutter-md px-page-margin pt-gutter-md">
        {/* Status & Next Actor Banner */}
        <section
          className={`rounded-lg p-gutter-md flex flex-col gap-gutter-xs ${
            info.tone === 'success'
              ? 'bg-success-container text-on-success-container'
              : info.tone === 'error'
              ? 'bg-light-error-container text-light-on-error-container'
              : 'bg-warning-container text-on-warning-container'
          }`}
        >
          <div className="flex items-center justify-between gap-gutter-sm">
            <span className="font-title text-title-md">{info.badgeLabel}</span>
            <span className="font-mono text-label-sm px-2.5 py-0.5 rounded-full bg-light-surface-container-lowest text-light-on-surface tabular-nums">
              PIN gặp mặt: {handoverPin}
            </span>
          </div>
          <p className="font-body text-body-md">{info.nextStep}</p>
        </section>

        {order.blocking_order_id && (
          <div
            role="alert"
            className="rounded-lg bg-light-error-container text-light-on-error-container p-gutter-md flex items-start gap-gutter-sm"
          >
            <span className="material-symbols-outlined text-[20px] mt-0.5 shrink-0">warning</span>
            <div className="flex flex-col gap-0.5">
              <span className="font-label text-label-lg">
                Món đồ đang bị giữ ở đơn #{order.blocking_order_id}
              </span>
              <span className="font-body text-body-md">
                Cần hoàn tất xác nhận trả ở đơn trước để mở khóa bàn giao cho đơn này.
              </span>
            </div>
          </div>
        )}

        {actionError && (
          <div
            role="alert"
            className="rounded-md bg-light-error-container text-light-on-error-container p-gutter-sm font-body text-body-md"
          >
            {actionError}
          </div>
        )}

        {/* Agreed Terms Summary + Immutable Revision Lock */}
        <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
          <div className="flex gap-gutter-sm items-center">
            <div className="w-16 aspect-[4/3] rounded-md overflow-hidden shrink-0 bg-light-surface-container">
              <AuthPhoto fallbackKey={order.listing_id} alt={order.title} />
            </div>
            <div className="flex-1 flex flex-col gap-0.5">
              <h2 className="font-title text-title-md text-light-on-surface">{order.title}</h2>
              <span className="font-body text-body-md text-light-on-surface-variant">
                Điểm hẹn: {order.pickup_point}
              </span>
              <span className="font-label text-label-sm text-light-on-surface-variant tabular-nums">
                {formatShortDateRange(order.quote.start_date, order.quote.end_date)}
              </span>
            </div>
          </div>

          <div className="border-t border-light-outline-variant pt-gutter-sm flex flex-col gap-gutter-xs">
            <div className="flex justify-between font-body text-body-md text-light-on-surface-variant">
              <span>Phụ kiện đã chốt</span>
              <span className="text-light-on-surface">
                {order.accessories.join(', ') || 'Không có'}
              </span>
            </div>
            <div className="flex justify-between font-body text-body-md text-light-on-surface-variant">
              <span>
                Tiền thuê ({formatVnd(order.quote.daily_rate)}/ngày × {order.quote.days} ngày)
              </span>
              <span className="text-light-on-surface tabular-nums">
                {formatVnd(order.quote.rent)}
              </span>
            </div>
            <div className="flex justify-between font-body text-body-md text-light-on-surface-variant">
              <span>Tổng cần trao lúc giao (gồm 1.000đ phí + cọc)</span>
              <span className="font-label text-label-lg text-light-primary tabular-nums">
                {formatVnd(order.quote.pickup_total)}
              </span>
            </div>
            <div className="flex justify-between font-body text-body-md text-light-on-surface-variant">
              <span>Trong đó tiền cọc hoàn lại khi trả</span>
              <span className="text-light-on-surface tabular-nums">
                {formatVnd(order.quote.deposit)}
              </span>
            </div>
            {isOwner && (
              <div className="flex justify-between font-body text-body-md text-light-tertiary pt-1 border-t border-dashed border-light-outline-variant">
                <span>Tiền thuê thực nhận của chủ đồ (sau 1.000đ phí)</span>
                <span className="font-label text-label-lg tabular-nums">
                  {formatVnd(order.quote.owner_net)}
                </span>
              </div>
            )}
          </div>

          <div className="rounded-md bg-light-surface-container-low p-gutter-xs px-gutter-sm flex items-center gap-gutter-xs text-light-on-surface-variant">
            <span className="material-symbols-outlined text-[16px] text-light-primary">
              verified_user
            </span>
            <span className="font-label text-label-sm">
              Thỏa thuận khóa cứng theo phiên bản tin #{order.quote.listing_revision} lúc đặt — sửa tin không làm đổi giá đơn này.
            </span>
          </div>
        </section>

        {/* Receipts & Deposit Quick Cards */}
        <section className="grid grid-cols-2 gap-gutter-sm">
          <button
            type="button"
            onClick={() => setSubView('s09')}
            className="text-left rounded-lg bg-light-surface-container-low border border-light-outline-variant p-gutter-sm flex flex-col gap-1 hover:border-light-primary"
          >
            <span className="material-symbols-outlined text-[20px] text-light-primary">
              receipt_long
            </span>
            <span className="font-label text-label-md text-light-on-surface">
              S09 · Biên nhận giao & trả
            </span>
            <span className="font-label text-label-sm text-light-on-surface-variant">
              Giao: {order.pickup.length}/2 · Trả: {order.returned.length}/2
            </span>
          </button>

          <button
            type="button"
            onClick={() => setSubView('s10')}
            className="text-left rounded-lg bg-light-surface-container-low border border-light-outline-variant p-gutter-sm flex flex-col gap-1 hover:border-light-primary"
          >
            <span className="material-symbols-outlined text-[20px] text-light-tertiary">
              account_balance_wallet
            </span>
            <span className="font-label text-label-md text-light-on-surface">
              S10 · Kết quả tiền cọc
            </span>
            <span className="font-label text-label-sm text-light-on-surface-variant tabular-nums">
              Mức cọc: {formatVnd(order.quote.deposit)} ({order.deposit_result.status})
            </span>
          </button>
        </section>

        {/* Safe Campus Spots & Order Chat */}
        <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
          <div className="flex items-center justify-between">
            <h3 className="font-title text-title-md text-light-on-surface">Trao đổi theo đơn</h3>
            <span className="font-label text-label-sm text-light-on-surface-variant">
              Chốt vị trí & giờ gặp tại {order.pickup_point}
            </span>
          </div>

          {/* Quick Safe Spot Chips */}
          <div className="flex items-center gap-gutter-xs overflow-x-auto pb-1">
            {safeSpots.map((spot) => (
              <button
                key={spot}
                type="button"
                onClick={() => setChatText(`Mình hẹn gặp tại ${spot} nhé.`)}
                className="shrink-0 px-2.5 py-1 rounded-full bg-light-surface-container text-light-on-surface-variant hover:text-light-primary font-label text-label-sm"
              >
                + {spot}
              </button>
            ))}
          </div>

          <div className="flex flex-col gap-gutter-sm max-h-64 overflow-y-auto">
            {messages.length === 0 ? (
              <p className="font-body text-body-md text-light-on-surface-variant">
                Chưa có tin nhắn. Hãy chọn một điểm hẹn an toàn phía trên để nhắn cho đối phương.
              </p>
            ) : (
              messages.map((m) => {
                const isMine = m.sender_id === me?.id;
                const senderName =
                  m.sender_id === order.owner.id
                    ? order.owner.display_name
                    : order.renter.display_name;
                return (
                  <div
                    key={m.id}
                    className={`max-w-[85%] rounded-lg p-gutter-sm flex flex-col gap-1 ${
                      isMine
                        ? 'self-end bg-light-primary text-light-on-primary'
                        : 'self-start bg-light-surface-container-low text-light-on-surface'
                    }`}
                  >
                    <span className="font-body text-body-md">{m.text}</span>
                    <span
                      className={`font-label text-label-sm tabular-nums ${
                        isMine
                          ? 'text-light-on-primary-container'
                          : 'text-light-on-surface-variant'
                      }`}
                    >
                      {senderName} · {formatTimeVN(m.created_at)}
                    </span>
                  </div>
                );
              })
            )}

            {failedChatText && (
              <button
                type="button"
                onClick={() => handleSendChat(failedChatText)}
                className="self-end max-w-[85%] rounded-lg bg-light-error-container text-light-on-error-container p-gutter-sm flex items-center justify-between gap-gutter-sm"
              >
                <span className="font-label text-label-sm">
                  Gửi lỗi (&ldquo;{failedChatText}&rdquo;) · Chạm để thử lại
                </span>
                <span className="material-symbols-outlined text-[16px]">refresh</span>
              </button>
            )}
          </div>

          <form
            onSubmit={(e) => {
              e.preventDefault();
              handleSendChat();
            }}
            className="flex items-center gap-gutter-sm pt-gutter-xs border-t border-light-outline-variant"
          >
            <input
              type="text"
              value={chatText}
              onChange={(e) => setChatText(e.target.value)}
              placeholder="Nhắn hẹn giờ hoặc vị trí..."
              className="flex-1 min-h-[44px] px-3 rounded-full bg-light-surface-container-low border border-light-outline-variant font-body text-body-md text-light-on-surface focus:border-light-primary focus:outline-none"
            />
            <button
              type="submit"
              aria-label="Gửi tin nhắn"
              className="w-11 h-11 rounded-full bg-light-primary text-light-on-primary flex items-center justify-center shrink-0"
            >
              <span className="material-symbols-outlined text-[20px]">send</span>
            </button>
          </form>
        </section>

        {/* Modal for Reject / Cancel reason */}
        {reasonModal && (
          <section className="rounded-lg bg-light-surface-container-lowest border border-light-primary p-gutter-md flex flex-col gap-gutter-sm">
            <h3 className="font-title text-title-md text-light-on-surface">
              {reasonModal === 'reject' ? 'Lý do từ chối yêu cầu' : 'Lý do hủy đơn thuê'}
            </h3>
            <input
              type="text"
              value={reasonInput}
              onChange={(e) => setReasonInput(e.target.value)}
              className="w-full min-h-[44px] px-3 rounded-md border border-light-outline-variant font-body text-body-md"
            />
            <div className="flex items-center gap-gutter-sm">
              <button
                type="button"
                onClick={() => setReasonModal(null)}
                className="flex-1 min-h-[44px] rounded-full border border-light-outline-variant font-label text-label-md"
              >
                Đóng
              </button>
              <button
                type="button"
                disabled={busy}
                onClick={handleRejectOrCancel}
                className="flex-1 min-h-[44px] rounded-full bg-light-error text-light-on-error font-label text-label-md"
              >
                Xác nhận {reasonModal === 'reject' ? 'từ chối' : 'hủy đơn'}
              </button>
            </div>
          </section>
        )}
      </main>

      {/* Sticky Bottom Action Bar */}
      <footer className="fixed bottom-0 left-0 lg:left-60 right-0 z-30 bg-light-surface-container-lowest border-t border-light-outline-variant px-page-margin py-gutter-sm">
        <div className="max-w-[680px] mx-auto flex items-center gap-gutter-sm">
          {canCancel && (
            <button
              type="button"
              onClick={() => setReasonModal('cancel')}
              className="inline-flex items-center justify-center min-h-[48px] px-4 py-3 rounded-full border border-light-outline-variant bg-light-surface-container-lowest text-light-error font-label text-label-md"
            >
              Hủy đơn
            </button>
          )}

          {!canCancel && oneSidedPickup && (
            <button
              type="button"
              onClick={() => onOpenReport(order.id, 'handover')}
              className="inline-flex items-center justify-center min-h-[48px] px-4 py-3 rounded-full border border-light-outline-variant bg-light-surface-container-lowest text-light-error font-label text-label-md"
            >
              Báo chưa nhận / Sự cố
            </button>
          )}

          {canReject && (
            <button
              type="button"
              onClick={() => setReasonModal('reject')}
              className="inline-flex items-center justify-center min-h-[48px] px-4 py-3 rounded-full border border-light-outline-variant bg-light-surface-container-lowest text-light-error font-label text-label-md"
            >
              Từ chối
            </button>
          )}

          {canApprove && (
            <button
              type="button"
              disabled={busy}
              onClick={handleApprove}
              className="flex-1 inline-flex items-center justify-center min-h-[48px] px-5 py-3 rounded-full bg-light-primary text-light-on-primary hover:bg-light-primary-container font-label text-label-lg"
            >
              Duyệt yêu cầu & giữ lịch
            </button>
          )}

          {canPickup && (
            <button
              type="button"
              onClick={() => setSubView('s09')}
              className="flex-1 inline-flex items-center justify-center min-h-[48px] px-5 py-3 rounded-full bg-light-primary text-light-on-primary hover:bg-light-primary-container font-label text-label-lg"
            >
              {isOwner ? 'Xác nhận đã giao máy' : 'Xác nhận đã nhận máy'}
            </button>
          )}

          {canReturn && (
            <button
              type="button"
              onClick={() => setSubView('s09')}
              className="flex-1 inline-flex items-center justify-center min-h-[48px] px-5 py-3 rounded-full bg-light-primary text-light-on-primary hover:bg-light-primary-container font-label text-label-lg"
            >
              {isOwner ? 'Xác nhận đã nhận lại máy' : 'Xác nhận đã trả máy'}
            </button>
          )}

          {canDeposit && (
            <button
              type="button"
              onClick={() => setSubView('s10')}
              className="flex-1 inline-flex items-center justify-center min-h-[48px] px-5 py-3 rounded-full bg-light-primary text-light-on-primary hover:bg-light-primary-container font-label text-label-lg"
            >
              Ghi nhận kết quả hoàn cọc
            </button>
          )}

          {!canApprove && !canPickup && !canReturn && !canDeposit && (
            <button
              type="button"
              onClick={() => onOpenReport(order.id, 'other')}
              className="flex-1 inline-flex items-center justify-center min-h-[48px] px-5 py-3 rounded-full bg-light-secondary-container text-light-on-secondary-container font-label text-label-lg"
            >
              Báo sự cố đơn thuê
            </button>
          )}
        </div>
      </footer>
    </div>
  );
}
