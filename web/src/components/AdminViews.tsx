'use client';

import React, { useEffect, useState } from 'react';
import { api, ApiClientError } from '@/lib/api';
import { formatTimeVN, formatVnd } from '@/lib/format';
import type { Case, FeeEntry, Me, OwnerFees, Settlement } from '@/lib/types';

export type AdminTab = 'q01' | 'q02' | 'q03';

interface AdminWorkspaceProps {
  activeTab: AdminTab;
  onChangeTab: (tab: AdminTab) => void;
  onBackToStudent: () => void;
  onOpenOrder: (orderId: string) => void;
}

export function AdminWorkspace({
  activeTab,
  onChangeTab,
  onBackToStudent,
  onOpenOrder,
}: AdminWorkspaceProps) {
  // Q01 State
  const [verifFilter, setVerifFilter] = useState<'pending' | 'approved' | 'rejected'>('pending');
  const [verifications, setVerifications] = useState<Me[]>([]);
  const [selectedUser, setSelectedUser] = useState<Me | null>(null);
  const [reviewNote, setReviewNote] = useState('');
  const [q01Error, setQ01Error] = useState<string | null>(null);
  const [q01Busy, setQ01Busy] = useState(false);

  // Q02 State
  const [caseStatusFilter, setCaseStatusFilter] = useState<'open' | 'resolved'>('open');
  const [cases, setCases] = useState<Case[]>([]);
  const [selectedCase, setSelectedCase] = useState<Case | null>(null);
  const [resolutionText, setResolutionText] = useState('');
  const [handoverOutcome, setHandoverOutcome] = useState<'resume' | 'cancel_unhanded'>('resume');
  const [refundedInput, setRefundedInput] = useState('300000');
  const [q02Error, setQ02Error] = useState<string | null>(null);
  const [q02Busy, setQ02Busy] = useState(false);

  // Q03 State
  const [feeOwners, setFeeOwners] = useState<OwnerFees[]>([]);
  const [selectedOwnerId, setSelectedOwnerId] = useState<string>('');
  const [ownerEntries, setOwnerEntries] = useState<FeeEntry[]>([]);
  const [selectedOrderIds, setSelectedOrderIds] = useState<string[]>([]);
  const [receivedAmountInput, setReceivedAmountInput] = useState('');
  const [bankRefInput, setBankRefInput] = useState('VCB-SGU-DOISOAT');
  const [lastSettlement, setLastSettlement] = useState<Settlement | null>(null);
  const [q03Error, setQ03Error] = useState<string | null>(null);
  const [q03Busy, setQ03Busy] = useState(false);

  const loadQ01 = async (status = verifFilter) => {
    setQ01Error(null);
    try {
      const page = await api.adminListVerifications(status);
      setVerifications(page.items);
      setSelectedUser(page.items[0] || null);
      setReviewNote(page.items[0]?.review_note || '');
    } catch (e: any) {
      setQ01Error(e?.message || 'Không thể tải danh sách hồ sơ.');
    }
  };

  const loadQ02 = async (status = caseStatusFilter) => {
    setQ02Error(null);
    try {
      const page = await api.adminListCases(status);
      setCases(page.items);
      setSelectedCase(page.items[0] || null);
      setResolutionText(
        page.items[0]?.resolution ||
          'Hai bên xác nhận gặp lại tại sảnh nhà A Cơ sở 2 để hoàn tất bàn giao.',
      );
    } catch (e: any) {
      setQ02Error(e?.message || 'Không thể tải danh sách vụ việc.');
    }
  };

  const loadQ03Owners = async () => {
    setQ03Error(null);
    try {
      const page = await api.adminListFeeOwners();
      setFeeOwners(page.items);
      const firstId = page.items[0]?.owner.id || '';
      setSelectedOwnerId(firstId);
      if (firstId) {
        await loadQ03Entries(firstId);
      } else {
        setOwnerEntries([]);
        setSelectedOrderIds([]);
        setReceivedAmountInput('0');
      }
    } catch (e: any) {
      setQ03Error(e?.message || 'Không thể tải danh sách chủ đồ có phí.');
    }
  };

  const loadQ03Entries = async (ownerId: string) => {
    try {
      const page = await api.adminListOwnerFeeEntries(ownerId, 'outstanding');
      setOwnerEntries(page.items);
      const ids = page.items.map((x) => x.order_id);
      setSelectedOrderIds(ids);
      const sum = page.items.reduce((acc, x) => acc + x.total, 0);
      setReceivedAmountInput(String(sum));
    } catch (e: any) {
      setQ03Error(e?.message || 'Không thể tải các đơn chưa đối soát.');
    }
  };

  useEffect(() => {
    if (activeTab === 'q01') loadQ01();
    if (activeTab === 'q02') loadQ02();
    if (activeTab === 'q03') loadQ03Owners();
  }, [activeTab]);

  const handleReviewStudent = async (decision: 'approve' | 'reject') => {
    if (!selectedUser) return;
    setQ01Busy(true);
    setQ01Error(null);
    try {
      await api.adminReviewVerification(
        selectedUser.id,
        decision,
        reviewNote.trim() || undefined,
      );
      await loadQ01();
    } catch (e: any) {
      if (e instanceof ApiClientError && e.code === 'student_code_taken') {
        setQ01Error(
          `Mã sinh viên ${selectedUser.student_code} đã thuộc về một tài khoản đã duyệt khác. Giữ nguyên hồ sơ để kiểm tra trực tiếp.`,
        );
      } else {
        setQ01Error(e?.message || 'Không thể cập nhật trạng thái duyệt.');
      }
    } finally {
      setQ01Busy(false);
    }
  };

  const handleResolveCase = async () => {
    if (!selectedCase) return;
    setQ02Busy(true);
    setQ02Error(null);
    try {
      const payload: {
        resolution: string;
        refunded?: number;
        handover_outcome?: 'resume' | 'cancel_unhanded';
      } = {
        resolution: resolutionText.trim(),
      };
      if (selectedCase.category === 'handover') {
        payload.handover_outcome = handoverOutcome;
      }
      if (selectedCase.category === 'deposit') {
        payload.refunded = Number(refundedInput.replace(/\D/g, '')) || 0;
      }
      await api.adminResolveCase(selectedCase.id, payload);
      await loadQ02();
    } catch (e: any) {
      setQ02Error(e?.message || 'Không thể lưu quyết định xử lý vụ việc.');
    } finally {
      setQ02Busy(false);
    }
  };

  const toggleOrderSelection = (orderId: string) => {
    setSelectedOrderIds((prev) => {
      const next = prev.includes(orderId)
        ? prev.filter((id) => id !== orderId)
        : [...prev, orderId];
      const sum = ownerEntries
        .filter((e) => next.includes(e.order_id))
        .reduce((acc, e) => acc + e.total, 0);
      setReceivedAmountInput(String(sum));
      return next;
    });
  };

  const handleCreateSettlement = async () => {
    if (!selectedOwnerId || selectedOrderIds.length === 0) return;
    setQ03Busy(true);
    setQ03Error(null);
    try {
      const amount = Number(receivedAmountInput.replace(/\D/g, '')) || 0;
      const stl = await api.adminCreateSettlement({
        owner_id: selectedOwnerId,
        order_ids: selectedOrderIds,
        received_amount: amount,
        reference: bankRefInput.trim(),
      });
      setLastSettlement(stl);
      await loadQ03Owners();
    } catch (e: any) {
      setQ03Error(e?.message || 'Số tiền lệch hoặc đơn đã được đối soát. Vui lòng kiểm tra lại.');
    } finally {
      setQ03Busy(false);
    }
  };

  return (
    <div className="min-h-screen w-full flex flex-col lg:flex-row bg-light-surface">
      {/* Persistent Admin Sidebar Rail on Desktop + Mobile Top Switcher */}
      <aside className="lg:w-64 shrink-0 bg-light-surface-container-lowest border-b lg:border-b-0 lg:border-r border-light-outline-variant p-gutter-md flex flex-col justify-between gap-gutter-md">
        <div className="flex flex-col gap-gutter-md">
          <div className="flex items-center justify-between gap-gutter-sm">
            <div className="flex items-center gap-gutter-sm">
              <div className="w-9 h-9 rounded-md bg-light-primary text-light-on-primary flex items-center justify-center shrink-0">
                <span className="material-symbols-outlined text-[20px]">admin_panel_settings</span>
              </div>
              <div className="flex flex-col">
                <span className="font-title text-title-md text-light-on-surface">Quản trị ĐHSG</span>
                <span className="font-label text-label-sm text-light-on-surface-variant">
                  Thuê Đồ Sinh Viên
                </span>
              </div>
            </div>
            <button
              type="button"
              onClick={onBackToStudent}
              className="lg:hidden min-h-[40px] px-3 rounded-full border border-light-outline-variant font-label text-label-sm text-light-on-surface flex items-center gap-1"
            >
              <span className="material-symbols-outlined text-[16px]">arrow_back</span>
              Về trang SV
            </button>
          </div>

          <nav
            aria-label="Điều hướng quản trị"
            className="grid grid-cols-3 lg:flex lg:flex-col gap-gutter-xs"
          >
            <button
              type="button"
              onClick={() => onChangeTab('q01')}
              className={`min-h-[44px] px-3 rounded-full flex items-center justify-center lg:justify-start gap-gutter-xs lg:gap-gutter-sm font-label text-label-md lg:text-label-lg transition-colors ${
                activeTab === 'q01'
                  ? 'bg-light-secondary-container text-light-on-surface'
                  : 'text-light-on-surface-variant hover:bg-light-surface-container'
              }`}
            >
              <span className="material-symbols-outlined text-[20px]">verified_user</span>
              <span>Duyệt SV (Q01)</span>
            </button>
            <button
              type="button"
              onClick={() => onChangeTab('q02')}
              className={`min-h-[44px] px-3 rounded-full flex items-center justify-center lg:justify-start gap-gutter-xs lg:gap-gutter-sm font-label text-label-md lg:text-label-lg transition-colors ${
                activeTab === 'q02'
                  ? 'bg-light-secondary-container text-light-on-surface'
                  : 'text-light-on-surface-variant hover:bg-light-surface-container'
              }`}
            >
              <span className="material-symbols-outlined text-[20px]">gavel</span>
              <span>Vụ việc (Q02)</span>
            </button>
            <button
              type="button"
              onClick={() => onChangeTab('q03')}
              className={`min-h-[44px] px-3 rounded-full flex items-center justify-center lg:justify-start gap-gutter-xs lg:gap-gutter-sm font-label text-label-md lg:text-label-lg transition-colors ${
                activeTab === 'q03'
                  ? 'bg-light-secondary-container text-light-on-surface'
                  : 'text-light-on-surface-variant hover:bg-light-surface-container'
              }`}
            >
              <span className="material-symbols-outlined text-[20px]">fact_check</span>
              <span>Đối soát (Q03)</span>
            </button>
          </nav>
        </div>

        <button
          type="button"
          onClick={onBackToStudent}
          className="hidden lg:flex min-h-[44px] px-3 rounded-full border border-light-outline-variant text-light-on-surface items-center gap-gutter-sm font-label text-label-md hover:bg-light-surface-container"
        >
          <span className="material-symbols-outlined text-[18px]">arrow_back</span>
          Về giao diện sinh viên
        </button>
      </aside>

      {/* Main Admin Workspace */}
      <main className="flex-1 p-gutter-md lg:p-gutter-xl flex flex-col gap-gutter-lg max-w-[1200px]">
        {activeTab === 'q01' && (
          <>
            <header className="flex flex-wrap items-center justify-between gap-gutter-md">
              <div className="flex flex-col gap-1">
                <h1 className="font-headline text-headline-md lg:text-headline-lg text-light-on-surface">
                  Q01 · Hàng đợi duyệt sinh viên
                </h1>
                <p className="font-body text-body-md text-light-on-surface-variant">
                  Đối chiếu thẻ sinh viên hoặc cổng sinh viên ĐH Sài Gòn trực tiếp trước khi cấp quyền đăng và thuê đồ (không lưu ảnh thẻ).
                </p>
              </div>
              <div className="flex items-center gap-gutter-xs">
                {(['pending', 'approved', 'rejected'] as const).map((st) => (
                  <button
                    key={st}
                    type="button"
                    onClick={() => {
                      setVerifFilter(st);
                      loadQ01(st);
                    }}
                    className={`min-h-[38px] px-3.5 rounded-full font-label text-label-md ${
                      verifFilter === st
                        ? 'bg-light-secondary-container text-light-on-secondary-container'
                        : 'bg-light-surface-container-lowest border border-light-outline-variant text-light-on-surface-variant'
                    }`}
                  >
                    {st === 'pending' ? 'Chờ duyệt' : st === 'approved' ? 'Đã duyệt' : 'Từ chối'}
                  </button>
                ))}
              </div>
            </header>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-gutter-lg items-start">
              <section className="lg:col-span-7 rounded-lg bg-light-surface-container-lowest border border-light-outline-variant overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead className="bg-light-surface-container-low border-b border-light-outline-variant font-label text-label-md text-light-on-surface-variant">
                    <tr>
                      <th className="py-3 px-4">Sinh viên</th>
                      <th className="py-3 px-4">MSSV</th>
                      <th className="py-3 px-4">Khoa / Lớp</th>
                      <th className="py-3 px-4">Trạng thái</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-light-outline-variant font-body text-body-md">
                    {verifications.length === 0 ? (
                      <tr>
                        <td colSpan={4} className="py-8 px-4 text-center text-light-on-surface-variant">
                          Không có hồ sơ nào ở trạng thái này.
                        </td>
                      </tr>
                    ) : (
                      verifications.map((u) => (
                        <tr
                          key={u.id}
                          onClick={() => {
                            setSelectedUser(u);
                            setReviewNote(u.review_note || '');
                            setQ01Error(null);
                          }}
                          className={`cursor-pointer ${
                            selectedUser?.id === u.id
                              ? 'bg-light-secondary-container text-light-on-surface'
                              : 'hover:bg-light-surface-container-low'
                          }`}
                        >
                          <td className="py-3 px-4 font-label text-label-lg">
                            {u.full_name || u.display_name}
                          </td>
                          <td className="py-3 px-4 font-mono text-mono-sm tabular-nums">
                            {u.student_code || '—'}
                          </td>
                          <td className="py-3 px-4 text-light-on-surface-variant">
                            {u.faculty || '—'} · {u.class_name || '—'}
                          </td>
                          <td className="py-3 px-4">
                            <span
                              className={`px-2.5 py-0.5 rounded-full font-label text-label-sm ${
                                u.verification === 'approved'
                                  ? 'bg-success-container text-on-success-container'
                                  : u.verification === 'rejected'
                                  ? 'bg-light-error-container text-light-on-error-container'
                                  : 'bg-warning-container text-on-warning-container'
                              }`}
                            >
                              {u.verification === 'approved'
                                ? 'Đã duyệt'
                                : u.verification === 'rejected'
                                ? 'Đã từ chối'
                                : 'Chờ đối chiếu'}
                            </span>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </section>

              <section className="lg:col-span-5 rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-lg flex flex-col gap-gutter-md">
                {selectedUser ? (
                  <>
                    <div className="flex flex-wrap items-center justify-between gap-gutter-sm">
                      <h2 className="font-title text-title-lg text-light-on-surface">
                        Hồ sơ: {selectedUser.full_name || selectedUser.display_name}
                      </h2>
                      <span className="font-mono text-mono-sm text-light-on-surface-variant tabular-nums">
                        MSSV {selectedUser.student_code || '—'}
                      </span>
                    </div>

                    {q01Error && (
                      <div
                        role="alert"
                        className="rounded-md bg-light-error-container text-light-on-error-container p-gutter-sm flex items-start gap-gutter-sm"
                      >
                        <span className="material-symbols-outlined text-[20px] mt-0.5 shrink-0">
                          error
                        </span>
                        <div className="flex flex-col gap-0.5">
                          <span className="font-label text-label-md">
                            Không thể duyệt hồ sơ
                          </span>
                          <span className="font-body text-body-md">{q01Error}</span>
                        </div>
                      </div>
                    )}

                    <div className="grid grid-cols-2 gap-gutter-sm text-body-md">
                      <div className="flex flex-col">
                        <span className="font-label text-label-sm text-light-on-surface-variant">
                          Tên hiển thị
                        </span>
                        <span>{selectedUser.display_name}</span>
                      </div>
                      <div className="flex flex-col">
                        <span className="font-label text-label-sm text-light-on-surface-variant">
                          Email đăng nhập
                        </span>
                        <span className="break-all">{selectedUser.email}</span>
                      </div>
                      <div className="flex flex-col">
                        <span className="font-label text-label-sm text-light-on-surface-variant">
                          Lớp
                        </span>
                        <span>{selectedUser.class_name || '—'}</span>
                      </div>
                      <div className="flex flex-col">
                        <span className="font-label text-label-sm text-light-on-surface-variant">
                          Khoa
                        </span>
                        <span>{selectedUser.faculty || '—'}</span>
                      </div>
                    </div>

                    <div className="flex flex-col gap-1">
                      <label className="font-label text-label-md text-light-on-surface">
                        Ghi chú duyệt / lý do từ chối
                      </label>
                      <textarea
                        rows={2}
                        value={reviewNote}
                        onChange={(e) => setReviewNote(e.target.value)}
                        placeholder="Nhập ghi chú đối chiếu trực tiếp hoặc lý do từ chối..."
                        className="w-full p-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md focus:border-light-primary focus:outline-none"
                      />
                    </div>

                    <div className="flex items-center gap-gutter-sm">
                      <button
                        type="button"
                        disabled={q01Busy}
                        onClick={() => handleReviewStudent('reject')}
                        className="flex-1 min-h-[48px] px-4 rounded-full border border-light-error text-light-error font-label text-label-lg hover:bg-light-error-container disabled:opacity-50"
                      >
                        Từ chối hồ sơ
                      </button>
                      <button
                        type="button"
                        disabled={q01Busy}
                        onClick={() => handleReviewStudent('approve')}
                        className="flex-1 min-h-[48px] px-4 rounded-full bg-light-primary text-light-on-primary font-label text-label-lg hover:bg-light-primary-container disabled:opacity-50"
                      >
                        Duyệt sinh viên
                      </button>
                    </div>
                  </>
                ) : (
                  <p className="text-body-md text-light-on-surface-variant">
                    Chọn một hồ sơ sinh viên ở bảng bên trái để đối chiếu và duyệt.
                  </p>
                )}
              </section>
            </div>
          </>
        )}

        {activeTab === 'q02' && (
          <>
            <header className="flex flex-wrap items-center justify-between gap-gutter-md">
              <div className="flex flex-col gap-1">
                <h1 className="font-headline text-headline-md lg:text-headline-lg text-light-on-surface">
                  Q02 · Xử lý báo cáo và vụ việc
                </h1>
                <p className="font-body text-body-md text-light-on-surface-variant">
                  Xem bằng chứng bàn giao, biên nhận hai phía và chốt quyết định cho tranh chấp giao nhận hoặc tiền cọc.
                </p>
              </div>
              <div className="flex items-center gap-gutter-sm">
                <button
                  type="button"
                  onClick={() => {
                    setCaseStatusFilter('open');
                    loadQ02('open');
                  }}
                  className={`min-h-[38px] px-3.5 rounded-full font-label text-label-md ${
                    caseStatusFilter === 'open'
                      ? 'bg-light-secondary-container text-light-on-surface'
                      : 'bg-light-surface-container-lowest border border-light-outline-variant text-light-on-surface-variant'
                  }`}
                >
                  Đang mở
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setCaseStatusFilter('resolved');
                    loadQ02('resolved');
                  }}
                  className={`min-h-[38px] px-3.5 rounded-full font-label text-label-md ${
                    caseStatusFilter === 'resolved'
                      ? 'bg-light-secondary-container text-light-on-surface'
                      : 'bg-light-surface-container-lowest border border-light-outline-variant text-light-on-surface-variant'
                  }`}
                >
                  Đã xử lý
                </button>
              </div>
            </header>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-gutter-lg items-start">
              <section className="lg:col-span-6 rounded-lg bg-light-surface-container-lowest border border-light-outline-variant overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead className="bg-light-surface-container-low border-b border-light-outline-variant font-label text-label-md text-light-on-surface-variant">
                    <tr>
                      <th className="py-3 px-4">Mã vụ việc</th>
                      <th className="py-3 px-4">Loại tranh chấp</th>
                      <th className="py-3 px-4">Đơn / Tin</th>
                      <th className="py-3 px-4">Trạng thái</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-light-outline-variant font-body text-body-md">
                    {cases.length === 0 ? (
                      <tr>
                        <td colSpan={4} className="py-8 px-4 text-center text-light-on-surface-variant">
                          Chưa có vụ việc nào trong danh sách này.
                        </td>
                      </tr>
                    ) : (
                      cases.map((c) => (
                        <tr
                          key={c.id}
                          onClick={() => {
                            setSelectedCase(c);
                            setResolutionText(c.resolution || '');
                            setQ02Error(null);
                          }}
                          className={`cursor-pointer ${
                            selectedCase?.id === c.id
                              ? 'bg-light-secondary-container text-light-on-surface'
                              : 'hover:bg-light-surface-container-low'
                          }`}
                        >
                          <td className="py-3 px-4 font-mono text-mono-sm tabular-nums">{c.id}</td>
                          <td className="py-3 px-4 font-label text-label-md">{c.category}</td>
                          <td className="py-3 px-4 text-light-on-surface-variant">
                            {c.target_type === 'order' ? `Đơn ${c.target_id}` : `Tin ${c.target_id}`}
                          </td>
                          <td className="py-3 px-4">
                            <span
                              className={`px-2 py-0.5 rounded-full font-label text-label-sm ${
                                c.status === 'open'
                                  ? 'bg-warning-container text-on-warning-container'
                                  : 'bg-success-container text-on-success-container'
                              }`}
                            >
                              {c.status === 'open' ? 'Đang mở' : 'Đã xử lý'}
                            </span>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </section>

              <section className="lg:col-span-6 rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-lg flex flex-col gap-gutter-md">
                {selectedCase ? (
                  <>
                    <div className="flex flex-wrap items-center justify-between gap-gutter-sm">
                      <h2 className="font-title text-title-lg text-light-on-surface">
                        Vụ việc {selectedCase.id}
                      </h2>
                      <div className="flex items-center gap-gutter-xs">
                        {selectedCase.target_type === 'order' && (
                          <button
                            type="button"
                            onClick={() => onOpenOrder(selectedCase.target_id)}
                            className="px-3 py-1 rounded-full border border-light-outline-variant font-label text-label-sm text-light-primary hover:bg-light-surface-container"
                          >
                            Mở chi tiết đơn & biên nhận
                          </button>
                        )}
                        <span className="px-2.5 py-1 rounded-full bg-warning-container text-on-warning-container font-label text-label-sm">
                          {selectedCase.category}
                        </span>
                      </div>
                    </div>

                    <div className="rounded-md bg-light-surface-container-low p-gutter-sm flex flex-col gap-1">
                      <span className="font-label text-label-md text-light-on-surface">
                        Nội dung báo cáo ({formatTimeVN(selectedCase.created_at)})
                      </span>
                      <p className="font-body text-body-md text-light-on-surface-variant">
                        {selectedCase.detail}
                      </p>
                    </div>

                    {q02Error && (
                      <div
                        role="alert"
                        className="rounded-md bg-light-error-container text-light-on-error-container p-gutter-sm font-body text-body-md"
                      >
                        {q02Error}
                      </div>
                    )}

                    {selectedCase.category === 'handover' && selectedCase.status === 'open' && (
                      <div className="flex flex-col gap-gutter-xs">
                        <span className="font-label text-label-md text-light-on-surface">
                          Quyết định xử lý (tranh chấp giao một phía · AC-10)
                        </span>
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-gutter-sm">
                          <label
                            className={`flex items-center gap-2 p-3 rounded-md border cursor-pointer ${
                              handoverOutcome === 'resume'
                                ? 'border-light-primary bg-light-secondary-container text-light-on-surface'
                                : 'border-light-outline-variant bg-light-surface-container-lowest'
                            }`}
                          >
                            <input
                              type="radio"
                              name="handover_outcome"
                              checked={handoverOutcome === 'resume'}
                              onChange={() => setHandoverOutcome('resume')}
                              className="text-light-primary"
                            />
                            <span className="font-label text-label-md">
                              Cho tiếp tục giao (resume)
                            </span>
                          </label>
                          <label
                            className={`flex items-center gap-2 p-3 rounded-md border cursor-pointer ${
                              handoverOutcome === 'cancel_unhanded'
                                ? 'border-light-primary bg-light-secondary-container text-light-on-surface'
                                : 'border-light-outline-variant bg-light-surface-container-lowest'
                            }`}
                          >
                            <input
                              type="radio"
                              name="handover_outcome"
                              checked={handoverOutcome === 'cancel_unhanded'}
                              onChange={() => setHandoverOutcome('cancel_unhanded')}
                              className="text-light-primary"
                            />
                            <span className="font-label text-label-md">
                              Đóng đơn chưa giao (0đ phí)
                            </span>
                          </label>
                        </div>
                      </div>
                    )}

                    {selectedCase.category === 'deposit' && selectedCase.status === 'open' && (
                      <div className="flex flex-col gap-1">
                        <label className="font-label text-label-md text-light-on-surface">
                          Số tiền cọc chốt hoàn cho người thuê (đ)
                        </label>
                        <input
                          type="number"
                          value={refundedInput}
                          onChange={(e) => setRefundedInput(e.target.value)}
                          className="w-full min-h-[48px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-title text-title-md text-light-primary tabular-nums"
                        />
                      </div>
                    )}

                    <div className="flex flex-col gap-1">
                      <label className="font-label text-label-md text-light-on-surface">
                        Lý do và kết luận gửi hai bên
                      </label>
                      <textarea
                        rows={2}
                        value={resolutionText}
                        onChange={(e) => setResolutionText(e.target.value)}
                        placeholder="Nhập quyết định phân xử..."
                        className="w-full p-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md focus:border-light-primary focus:outline-none"
                      />
                    </div>

                    {selectedCase.status === 'open' && (
                      <button
                        type="button"
                        disabled={q02Busy}
                        onClick={handleResolveCase}
                        className="w-full min-h-[48px] px-6 rounded-full bg-light-primary text-light-on-primary hover:bg-light-primary-container font-label text-label-lg disabled:opacity-50"
                      >
                        Lưu quyết định xử lý
                      </button>
                    )}
                  </>
                ) : (
                  <p className="text-body-md text-light-on-surface-variant">
                    Chọn một vụ việc bên trái để xem bằng chứng và ra quyết định.
                  </p>
                )}
              </section>
            </div>
          </>
        )}

        {activeTab === 'q03' && (
          <>
            <header className="flex flex-wrap items-center justify-between gap-gutter-md">
              <div className="flex flex-col gap-1">
                <h1 className="font-headline text-headline-md lg:text-headline-lg text-light-on-surface">
                  Q03 · Đối soát phí theo chủ đồ
                </h1>
                <p className="font-body text-body-md text-light-on-surface-variant">
                  Chọn chủ đồ, gom các đơn chưa đối soát cùng đợt (2.000đ/đơn = 1.000đ chủ đồ + 1.000đ thu hộ người thuê) và xác nhận số tiền thực nhận.
                </p>
              </div>
              <div className="flex flex-wrap items-center gap-gutter-sm">
                <label className="font-label text-label-md text-light-on-surface">Chủ đồ:</label>
                <select
                  value={selectedOwnerId}
                  onChange={(e) => {
                    setSelectedOwnerId(e.target.value);
                    loadQ03Entries(e.target.value);
                  }}
                  className="min-h-[44px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-label text-label-md text-light-on-surface"
                >
                  {feeOwners.length === 0 ? (
                    <option value="">Chưa có chủ đồ phát sinh phí</option>
                  ) : (
                    feeOwners.map((fo) => (
                      <option key={fo.owner.id} value={fo.owner.id}>
                        {fo.owner.display_name} (Còn nợ {formatVnd(fo.summary.outstanding)} · Đã đối soát{' '}
                        {formatVnd(fo.summary.settled)})
                      </option>
                    ))
                  )}
                </select>
              </div>
            </header>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-gutter-lg items-start">
              <section className="lg:col-span-7 rounded-lg bg-light-surface-container-lowest border border-light-outline-variant overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead className="bg-light-surface-container-low border-b border-light-outline-variant font-label text-label-md text-light-on-surface-variant">
                    <tr>
                      <th className="py-3 px-4">Chọn</th>
                      <th className="py-3 px-4">Mã đơn</th>
                      <th className="py-3 px-4">Phí chủ đồ</th>
                      <th className="py-3 px-4">Thu hộ người thuê</th>
                      <th className="py-3 px-4">Tổng</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-light-outline-variant font-body text-body-md tabular-nums">
                    {ownerEntries.length === 0 ? (
                      <tr>
                        <td colSpan={5} className="py-8 px-4 text-center text-light-on-surface-variant">
                          Chủ đồ này không còn đơn nào chờ đối soát.
                        </td>
                      </tr>
                    ) : (
                      ownerEntries.map((entry) => (
                        <tr key={entry.order_id} className="hover:bg-light-surface-container-low">
                          <td className="py-3 px-4">
                            <input
                              type="checkbox"
                              checked={selectedOrderIds.includes(entry.order_id)}
                              onChange={() => toggleOrderSelection(entry.order_id)}
                              className="w-4 h-4 rounded text-light-primary"
                            />
                          </td>
                          <td className="py-3 px-4 font-mono text-mono-sm">{entry.order_id}</td>
                          <td className="py-3 px-4">{formatVnd(entry.owner_fee)}</td>
                          <td className="py-3 px-4">{formatVnd(entry.renter_fee)}</td>
                          <td className="py-3 px-4 font-label text-label-md text-light-primary">
                            {formatVnd(entry.total)}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </section>

              <section className="lg:col-span-5 rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-lg flex flex-col gap-gutter-md">
                <div className="flex flex-wrap items-center justify-between gap-gutter-sm">
                  <h2 className="font-title text-title-lg text-light-on-surface">
                    Xác nhận đợt đối soát
                  </h2>
                  <span className="font-label text-label-lg text-light-primary tabular-nums">
                    {selectedOrderIds.length} đơn ·{' '}
                    {formatVnd(selectedOrderIds.length * 2000)}
                  </span>
                </div>

                {q03Error && (
                  <div
                    role="alert"
                    className="rounded-md bg-light-error-container text-light-on-error-container p-gutter-sm font-body text-body-md"
                  >
                    {q03Error}
                  </div>
                )}

                <div className="flex flex-col gap-1">
                  <label className="font-label text-label-md text-light-on-surface">
                    Số tiền thực nhận (đ)
                  </label>
                  <input
                    type="number"
                    value={receivedAmountInput}
                    onChange={(e) => setReceivedAmountInput(e.target.value)}
                    className="w-full min-h-[48px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-title text-title-md text-light-primary tabular-nums"
                  />
                </div>

                <div className="flex flex-col gap-1">
                  <label className="font-label text-label-md text-light-on-surface">
                    Mã tham chiếu chuyển khoản
                  </label>
                  <input
                    type="text"
                    value={bankRefInput}
                    onChange={(e) => setBankRefInput(e.target.value)}
                    className="w-full min-h-[48px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-mono text-body-md text-light-on-surface"
                  />
                </div>

                <button
                  type="button"
                  disabled={q03Busy || selectedOrderIds.length === 0}
                  onClick={handleCreateSettlement}
                  className="w-full min-h-[48px] px-6 rounded-full bg-light-primary text-light-on-primary hover:bg-light-primary-container font-label text-label-lg disabled:opacity-50"
                >
                  Ghi nhận đã nhận {formatVnd(Number(receivedAmountInput) || 0)}
                </button>

                {lastSettlement && (
                  <div className="rounded-md bg-success-container text-on-success-container p-gutter-sm flex flex-col gap-0.5">
                    <span className="font-label text-label-md">
                      Đã xác nhận đợt đối soát: {formatVnd(lastSettlement.received_amount)} (
                      {lastSettlement.order_ids.length} đơn)
                    </span>
                    <span className="font-body text-body-md tabular-nums">
                      Mã tham chiếu #{lastSettlement.reference} · Xác nhận bởi{' '}
                      {lastSettlement.confirmed_by} lúc {formatTimeVN(lastSettlement.confirmed_at)}
                    </span>
                  </div>
                )}
              </section>
            </div>
          </>
        )}
      </main>
    </div>
  );
}
