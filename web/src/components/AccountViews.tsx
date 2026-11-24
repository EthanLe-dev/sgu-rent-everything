'use client';

import React, { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { formatTimeVN, formatVnd } from '@/lib/format';
import type { Case, FeeEntry, FeeSummary, Me, Notice, Settlement } from '@/lib/types';

interface LoginScreenProps {
  onSuccess: (me: Me) => void;
  onCancel: () => void;
}

export function LoginScreen({ onSuccess, onCancel }: LoginScreenProps) {
  const [step, setStep] = useState<'email' | 'otp'>('email');
  const [email, setEmail] = useState('nguoithue@sgu.test');
  const [challengeId, setChallengeId] = useState('');
  const [otpCode, setOtpCode] = useState('');
  const [cooldown, setCooldown] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (cooldown <= 0) return;
    const t = setInterval(() => setCooldown((c) => Math.max(0, c - 1)), 1000);
    return () => clearInterval(t);
  }, [cooldown]);

  const handleSendOtp = async () => {
    setBusy(true);
    setError(null);
    try {
      const res = await api.requestOtp(email.trim());
      setChallengeId(res.challenge_id);
      setStep('otp');
      setCooldown(30);
    } catch (e: any) {
      if (e?.retryAfter) setCooldown(e.retryAfter);
      setError(e?.message || 'Không thể gửi mã OTP.');
    } finally {
      setBusy(false);
    }
  };

  const handleVerifyOtp = async () => {
    setBusy(true);
    setError(null);
    try {
      const res = await api.verifyOtp(challengeId, otpCode.trim());
      onSuccess(res.me);
    } catch (e: any) {
      setError(e?.message || 'Mã OTP không đúng hoặc đã hết hạn.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="min-h-[820px] w-full max-w-[440px] mx-auto bg-light-surface flex flex-col justify-between px-page-margin py-gutter-lg">
      <main className="flex flex-col gap-gutter-lg">
        <header className="flex flex-col gap-gutter-sm pt-gutter-md">
          <div className="w-12 h-12 rounded-lg bg-light-primary text-light-on-primary flex items-center justify-center">
            <span className="material-symbols-outlined text-[26px]">school</span>
          </div>
          <h1 className="font-headline text-headline-lg text-light-on-surface">
            S01 · Đăng nhập sinh viên ĐH Sài Gòn
          </h1>
          <p className="font-body text-body-md text-light-on-surface-variant">
            Xác thực bằng email để thuê và cho thuê đồ tại Cơ sở 1, Cơ sở 2 hoặc Cơ sở Chính.
          </p>
        </header>

        {/* Quick Demo Account Pills */}
        <section className="rounded-lg bg-light-surface-container-low border border-light-outline-variant p-gutter-sm flex flex-col gap-gutter-xs">
          <span className="font-label text-label-sm text-light-on-surface-variant">
            Chọn nhanh tài khoản mẫu (xem mã OTP tại hộp thư Mailpit 127.0.0.1:8025):
          </span>
          <div className="flex flex-wrap gap-1.5">
            {[
              { label: 'Chủ đồ (Lan)', email: 'chudo@sgu.test' },
              { label: 'Người thuê (Minh)', email: 'nguoithue@sgu.test' },
              { label: 'Chờ duyệt', email: 'choduyet@sgu.test' },
              { label: 'Quản trị viên', email: 'admin@sgu.test' },
            ].map((acc) => (
              <button
                key={acc.email}
                type="button"
                onClick={() => {
                  setEmail(acc.email);
                  setStep('email');
                  setError(null);
                }}
                className={`px-2.5 py-1 rounded-full font-label text-label-sm border ${
                  email === acc.email
                    ? 'bg-light-secondary-container border-light-primary text-light-on-secondary-container'
                    : 'bg-light-surface-container-lowest border-light-outline-variant text-light-on-surface-variant'
                }`}
              >
                {acc.label}
              </button>
            ))}
          </div>
        </section>

        {step === 'email' ? (
          <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-md">
            <div className="flex flex-col gap-gutter-xs">
              <label
                htmlFor="login-email"
                className="font-label text-label-lg text-light-on-surface"
              >
                Email sinh viên
              </label>
              <input
                id="login-email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="mssv@sgu.edu.vn"
                className="w-full min-h-[48px] px-4 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-lg text-light-on-surface focus:border-light-primary focus:outline-none"
              />
              <span className="font-label text-label-sm text-light-on-surface-variant">
                Sau khi xác thực sẽ quay lại đúng trang hoặc đơn bạn đang mở.
              </span>
            </div>

            {error && (
              <div
                role="alert"
                className="rounded-md bg-light-error-container text-light-on-error-container p-gutter-sm flex items-start gap-gutter-sm"
              >
                <span className="material-symbols-outlined text-[18px] mt-0.5 shrink-0">
                  error
                </span>
                <span className="font-body text-body-md">{error}</span>
              </div>
            )}

            <button
              type="button"
              disabled={busy || !email.trim()}
              onClick={handleSendOtp}
              className="w-full inline-flex items-center justify-center min-h-[48px] px-6 py-3 rounded-full bg-light-primary text-light-on-primary hover:bg-light-primary-container font-label text-label-lg disabled:opacity-50"
            >
              {busy ? 'Đang gửi mã...' : 'Gửi mã OTP'}
            </button>
          </section>
        ) : (
          <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-md">
            <div className="flex items-start justify-between gap-gutter-sm">
              <div className="flex flex-col gap-gutter-xs">
                <h2 className="font-title text-title-md text-light-on-surface">
                  Nhập mã xác thực 6 số
                </h2>
                <p className="font-body text-body-md text-light-on-surface-variant">
                  Mã đã gửi tới{' '}
                  <span className="font-label text-label-lg text-light-on-surface">
                    {email}
                  </span>
                </p>
              </div>
              <button
                type="button"
                onClick={() => setStep('email')}
                className="font-label text-label-md text-light-primary hover:underline shrink-0"
              >
                Đổi email
              </button>
            </div>

            <div className="flex flex-col gap-gutter-xs">
              <label
                htmlFor="otp-code"
                className="font-label text-label-md text-light-on-surface"
              >
                Mã OTP (hiệu lực 10 phút)
              </label>
              <input
                id="otp-code"
                type="text"
                inputMode="numeric"
                maxLength={6}
                value={otpCode}
                onChange={(e) => setOtpCode(e.target.value)}
                placeholder="123456"
                className="w-full min-h-[48px] px-4 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-mono text-title-lg tracking-widest text-center text-light-on-surface tabular-nums focus:border-light-primary focus:outline-none"
              />
            </div>

            {error && (
              <div
                role="alert"
                className="rounded-md bg-light-error-container text-light-on-error-container p-gutter-sm flex items-start gap-gutter-sm"
              >
                <span className="material-symbols-outlined text-[18px] mt-0.5 shrink-0">
                  error
                </span>
                <span className="font-body text-body-md">{error}</span>
              </div>
            )}

            <button
              type="button"
              disabled={busy || otpCode.trim().length < 6}
              onClick={handleVerifyOtp}
              className="w-full inline-flex items-center justify-center min-h-[48px] px-6 py-3 rounded-full bg-light-primary text-light-on-primary hover:bg-light-primary-container font-label text-label-lg disabled:opacity-50"
            >
              {busy ? 'Đang xác thực...' : 'Xác nhận và tiếp tục'}
            </button>

            <div className="flex items-center justify-between gap-gutter-sm pt-gutter-xs border-t border-light-outline-variant">
              <span className="font-label text-label-sm text-light-on-surface-variant tabular-nums">
                {cooldown > 0 ? `Gửi lại sau ${cooldown}s` : 'Chưa nhận được mã?'}
              </span>
              <button
                type="button"
                disabled={cooldown > 0 || busy}
                onClick={handleSendOtp}
                className="inline-flex items-center justify-center min-h-[40px] px-4 py-2 rounded-full bg-light-secondary-container text-light-on-secondary-container font-label text-label-md disabled:bg-light-surface-container-high disabled:text-light-on-surface-variant"
              >
                Gửi lại mã
              </button>
            </div>
          </section>
        )}
      </main>

      <footer className="pt-gutter-lg text-center">
        <button
          type="button"
          onClick={onCancel}
          className="font-label text-label-md text-light-primary hover:underline"
        >
          Quay về trang trước
        </button>
      </footer>
    </div>
  );
}

interface ProfileScreenProps {
  me: Me | null;
  unreadCount: number;
  onUpdatedMe: (me: Me) => void;
  onLogout: () => void;
  onOpenLogin: () => void;
  onOpenNotifications: () => void;
  onOpenMyListings: () => void;
  onOpenOwnerFees: () => void;
  onOpenCases: () => void;
  onOpenAdmin: () => void;
}

export function ProfileScreen({
  me,
  unreadCount,
  onUpdatedMe,
  onLogout,
  onOpenLogin,
  onOpenNotifications,
  onOpenMyListings,
  onOpenOwnerFees,
  onOpenCases,
  onOpenAdmin,
}: ProfileScreenProps) {
  const [displayName, setDisplayName] = useState(me?.display_name || '');
  const [fullName, setFullName] = useState(me?.full_name || '');
  const [studentCode, setStudentCode] = useState(me?.student_code || '');
  const [className, setClassName] = useState(me?.class_name || '');
  const [faculty, setFaculty] = useState(me?.faculty || 'Công nghệ Thông tin');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (me) {
      setDisplayName(me.display_name || '');
      setFullName(me.full_name || '');
      setStudentCode(me.student_code || '');
      setClassName(me.class_name || '');
      setFaculty(me.faculty || 'Công nghệ Thông tin');
    }
  }, [me]);

  if (!me) {
    return <LoginScreen onSuccess={onUpdatedMe} onCancel={() => {}} />;
  }

  const handleSaveVerification = async () => {
    setBusy(true);
    setMsg(null);
    setErr(null);
    try {
      const updated = await api.submitVerification({
        display_name: displayName.trim(),
        full_name: fullName.trim(),
        student_code: studentCode.trim(),
        class_name: className.trim(),
        faculty: faculty.trim(),
      });
      onUpdatedMe(updated);
      setMsg('Đã gửi thông tin xác minh sinh viên. Trạng thái: Chờ duyệt.');
    } catch (e: any) {
      setErr(e?.message || 'Không thể cập nhật hồ sơ xác minh.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col pb-24">
      <header className="sticky top-0 z-20 bg-light-surface border-b border-light-outline-variant px-page-margin py-gutter-sm flex items-center justify-between gap-gutter-sm">
        <h1 className="font-title text-title-lg text-light-on-surface">
          S02 · Cá nhân & Xác minh
        </h1>
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

      <main className="flex-1 flex flex-col gap-gutter-md px-page-margin pt-gutter-md">
        {/* Profile Summary & Verification Status */}
        <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
          <div className="flex items-center gap-gutter-sm">
            <div className="w-14 h-14 rounded-full bg-light-primary text-light-on-primary flex items-center justify-center font-headline text-headline-md shrink-0">
              {me.display_name.slice(0, 1).toUpperCase()}
            </div>
            <div className="flex-1 flex flex-col gap-1">
              <div className="flex items-center gap-gutter-xs flex-wrap">
                <h2 className="font-title text-title-md text-light-on-surface">
                  {me.display_name}
                </h2>
                <span
                  className={`inline-flex items-center gap-gutter-xs px-2.5 py-0.5 rounded-full font-label text-label-sm ${
                    me.verification === 'approved'
                      ? 'bg-success-container text-on-success-container'
                      : me.verification === 'rejected'
                      ? 'bg-light-error-container text-light-on-error-container'
                      : 'bg-warning-container text-on-warning-container'
                  }`}
                >
                  <span className="material-symbols-outlined text-[14px] material-fill">
                    {me.verification === 'approved'
                      ? 'verified'
                      : me.verification === 'rejected'
                      ? 'error'
                      : 'schedule'}
                  </span>
                  <span>
                    {me.verification === 'approved'
                      ? 'Đã duyệt'
                      : me.verification === 'rejected'
                      ? 'Bị từ chối'
                      : me.verification === 'pending'
                      ? 'Chờ duyệt'
                      : 'Chưa nộp xác minh'}
                  </span>
                </span>
              </div>
              <span className="font-body text-body-md text-light-on-surface-variant tabular-nums">
                {me.email} · MSSV: {me.student_code || 'Chưa khai'} · {me.faculty || 'ĐH Sài Gòn'}
              </span>
            </div>
          </div>

          {me.verification === 'rejected' && (
            <div className="rounded-md bg-light-error-container text-light-on-error-container p-gutter-sm flex flex-col gap-1">
              <span className="font-label text-label-md">
                Hồ sơ bị từ chối: {me.review_note || 'Thông tin chưa khớp thẻ sinh viên'}
              </span>
              <span className="font-body text-body-md">
                Cập nhật lại thông tin bên dưới và mang thẻ sinh viên hoặc mở cổng sinh viên để đối chiếu trực tiếp.
              </span>
            </div>
          )}
        </section>

        {/* Student Privacy Commitment Card (Trust & Safety) */}
        <section className="rounded-lg bg-light-surface-container-low border border-light-outline-variant p-gutter-md flex items-start gap-gutter-sm">
          <span className="material-symbols-outlined text-[22px] text-light-primary mt-0.5 shrink-0">
            shield_lock
          </span>
          <div className="flex flex-col gap-0.5">
            <span className="font-label text-label-lg text-light-on-surface">
              Cam kết bảo mật thông tin sinh viên
            </span>
            <p className="font-body text-body-md text-light-on-surface-variant">
              Hệ thống chỉ đối chiếu thẻ sinh viên trực tiếp một lần, tuyệt đối không thu thập hay lưu ảnh thẻ. Hồ sơ công khai trên tin đăng chỉ hiển thị Tên hiển thị và dấu Đã xác minh.
            </p>
          </div>
        </section>

        {/* Student Verification Form */}
        <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
          <h3 className="font-title text-title-md text-light-on-surface">
            Thông tin xác minh sinh viên
          </h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-gutter-sm">
            <div className="flex flex-col gap-1">
              <label className="font-label text-label-md text-light-on-surface">
                Tên hiển thị công khai
              </label>
              <input
                type="text"
                disabled={me.verification === 'approved'}
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                className="w-full min-h-[44px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md disabled:opacity-60"
              />
            </div>
            <div className="flex flex-col gap-1">
              <label className="font-label text-label-md text-light-on-surface">
                Họ và tên (theo thẻ SV)
              </label>
              <input
                type="text"
                disabled={me.verification === 'approved'}
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                className="w-full min-h-[44px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md disabled:opacity-60"
              />
            </div>
            <div className="flex flex-col gap-1">
              <label className="font-label text-label-md text-light-on-surface">
                Mã sinh viên (1 MSSV / 1 tài khoản duyệt)
              </label>
              <input
                type="text"
                disabled={me.verification === 'approved'}
                value={studentCode}
                onChange={(e) => setStudentCode(e.target.value)}
                className="w-full min-h-[44px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-mono text-body-md tabular-nums disabled:opacity-60"
              />
            </div>
            <div className="flex flex-col gap-1">
              <label className="font-label text-label-md text-light-on-surface">Lớp</label>
              <input
                type="text"
                disabled={me.verification === 'approved'}
                value={className}
                onChange={(e) => setClassName(e.target.value)}
                className="w-full min-h-[44px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md disabled:opacity-60"
              />
            </div>
            <div className="flex flex-col gap-1 sm:col-span-2">
              <label className="font-label text-label-md text-light-on-surface">Khoa</label>
              <input
                type="text"
                disabled={me.verification === 'approved'}
                value={faculty}
                onChange={(e) => setFaculty(e.target.value)}
                className="w-full min-h-[44px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md disabled:opacity-60"
              />
            </div>
          </div>

          {msg && (
            <div className="rounded-md bg-success-container text-on-success-container p-gutter-sm font-body text-body-md">
              {msg}
            </div>
          )}
          {err && (
            <div className="rounded-md bg-light-error-container text-light-on-error-container p-gutter-sm font-body text-body-md">
              {err}
            </div>
          )}

          {me.verification !== 'approved' && (
            <button
              type="button"
              disabled={busy}
              onClick={handleSaveVerification}
              className="w-full inline-flex items-center justify-center min-h-[48px] px-6 py-3 rounded-full bg-light-primary text-light-on-primary font-label text-label-lg disabled:opacity-50"
            >
              {busy ? 'Đang lưu...' : 'Lưu và gửi xác minh'}
            </button>
          )}
        </section>

        {/* Account Shortcuts */}
        <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant divide-y divide-light-outline-variant">
          <button
            type="button"
            onClick={onOpenMyListings}
            className="w-full min-h-[52px] px-gutter-md flex items-center justify-between gap-gutter-sm hover:bg-light-surface-container-low"
          >
            <div className="flex items-center gap-gutter-sm">
              <span className="material-symbols-outlined text-[20px] text-light-primary">
                inventory_2
              </span>
              <span className="font-label text-label-lg text-light-on-surface">
                S06 · Tin của tôi & quản lý lịch
              </span>
            </div>
            <span className="material-symbols-outlined text-[20px] text-light-on-surface-variant">
              chevron_right
            </span>
          </button>

          <button
            type="button"
            onClick={onOpenOwnerFees}
            className="w-full min-h-[52px] px-gutter-md flex items-center justify-between gap-gutter-sm hover:bg-light-surface-container-low"
          >
            <div className="flex items-center gap-gutter-sm">
              <span className="material-symbols-outlined text-[20px] text-light-primary">
                payments
              </span>
              <span className="font-label text-label-lg text-light-on-surface">
                S13 · Phí và đối soát của chủ đồ
              </span>
            </div>
            <span className="material-symbols-outlined text-[20px] text-light-on-surface-variant">
              chevron_right
            </span>
          </button>

          <button
            type="button"
            onClick={onOpenCases}
            className="w-full min-h-[52px] px-gutter-md flex items-center justify-between gap-gutter-sm hover:bg-light-surface-container-low"
          >
            <div className="flex items-center gap-gutter-sm">
              <span className="material-symbols-outlined text-[20px] text-light-primary">
                gavel
              </span>
              <span className="font-label text-label-lg text-light-on-surface">
                S12 · Báo cáo & Vụ việc của tôi
              </span>
            </div>
            <span className="material-symbols-outlined text-[20px] text-light-on-surface-variant">
              chevron_right
            </span>
          </button>

          {me.role === 'admin' && (
            <button
              type="button"
              onClick={onOpenAdmin}
              className="w-full min-h-[52px] px-gutter-md flex items-center justify-between gap-gutter-sm hover:bg-light-surface-container-low"
            >
              <div className="flex items-center gap-gutter-sm">
                <span className="material-symbols-outlined text-[20px] text-light-tertiary">
                  admin_panel_settings
                </span>
                <span className="font-label text-label-lg text-light-on-surface">
                  Q01–Q03 · Công cụ quản trị (Duyệt SV · Vụ việc · Đối soát)
                </span>
              </div>
              <span className="material-symbols-outlined text-[20px] text-light-on-surface-variant">
                chevron_right
              </span>
            </button>
          )}
        </section>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-gutter-sm">
          <button
            type="button"
            onClick={onOpenLogin}
            className="w-full inline-flex items-center justify-center gap-gutter-xs min-h-[48px] px-6 py-3 rounded-full border border-light-outline-variant bg-light-surface-container-lowest text-light-primary font-label text-label-lg"
          >
            <span className="material-symbols-outlined text-[20px]">switch_account</span>
            <span>Đổi nhanh tài khoản test</span>
          </button>

          <button
            type="button"
            onClick={onLogout}
            className="w-full inline-flex items-center justify-center gap-gutter-xs min-h-[48px] px-6 py-3 rounded-full border border-light-outline-variant bg-light-surface-container-lowest text-light-error hover:bg-light-error-container font-label text-label-lg"
          >
            <span className="material-symbols-outlined text-[20px]">logout</span>
            <span>Đăng xuất</span>
          </button>
        </div>
      </main>
    </div>
  );
}

interface NotificationsScreenProps {
  notices: Notice[];
  onBack: () => void;
  onSelectNotice: (n: Notice) => void;
  onMarkAllRead: () => void;
}

export function NotificationsScreen({
  notices,
  onBack,
  onSelectNotice,
  onMarkAllRead,
}: NotificationsScreenProps) {
  return (
    <div className="flex flex-col pb-20">
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
            S11 · Hộp thông báo
          </h1>
        </div>
        {notices.some((n) => !n.read_at) && (
          <button
            type="button"
            onClick={onMarkAllRead}
            className="px-3 py-2 rounded-full font-label text-label-md text-light-primary hover:bg-light-surface-container"
          >
            Đọc tất cả
          </button>
        )}
      </header>

      <main className="flex-1 flex flex-col gap-gutter-sm px-page-margin pt-gutter-md">
        {notices.length === 0 ? (
          <div className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-lg text-center font-body text-body-md text-light-on-surface-variant">
            Chưa có thông báo nào.
          </div>
        ) : (
          notices.map((n) => {
            const unread = !n.read_at;
            return (
              <button
                key={n.id}
                type="button"
                onClick={() => onSelectNotice(n)}
                className={`text-left rounded-lg p-gutter-md flex items-start gap-gutter-sm transition-colors ${
                  unread
                    ? 'bg-light-secondary-container text-light-on-secondary-container'
                    : 'bg-light-surface-container-lowest border border-light-outline-variant text-light-on-surface'
                }`}
              >
                <span className="material-symbols-outlined text-[22px] mt-0.5 shrink-0">
                  {n.target_type === 'case' ? 'gavel' : 'notifications_active'}
                </span>
                <div className="flex-1 flex flex-col gap-1">
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-label text-label-lg">{n.title}</span>
                    {unread && (
                      <span
                        className="w-2.5 h-2.5 rounded-full bg-light-primary shrink-0"
                        aria-label="Chưa đọc"
                      />
                    )}
                  </div>
                  <p className="font-body text-body-md">{n.body}</p>
                  <span className="font-label text-label-sm tabular-nums opacity-80">
                    {formatTimeVN(n.created_at)} · {n.target_type === 'order' ? 'Đơn' : 'Vụ việc'}{' '}
                    #{n.target_id}
                  </span>
                </div>
              </button>
            );
          })
        )}
      </main>
    </div>
  );
}

interface CasesScreenProps {
  initialTargetType?: 'listing' | 'order';
  initialTargetId?: string;
  initialCategory?: string;
  onBack: () => void;
}

export function CasesScreen({
  initialTargetType = 'order',
  initialTargetId = '',
  initialCategory = 'handover',
  onBack,
}: CasesScreenProps) {
  const [targetType, setTargetType] = useState<'listing' | 'order'>(initialTargetType);
  const [targetId, setTargetId] = useState(initialTargetId);
  const [category, setCategory] = useState(initialCategory);
  const [detail, setDetail] = useState('');
  const [cases, setCases] = useState<Case[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const loadCases = async () => {
    try {
      const page = await api.listCases();
      setCases(page.items);
    } catch {
      // ignore
    }
  };

  useEffect(() => {
    loadCases();
  }, []);

  const handleSubmitCase = async () => {
    if (!targetId.trim() || !detail.trim()) return;
    setBusy(true);
    setError(null);
    setSuccess(null);
    try {
      await api.createCase({
        target_type: targetType,
        target_id: targetId.trim(),
        category,
        detail: detail.trim(),
      });
      setDetail('');
      setSuccess('Đã gửi báo cáo vụ việc. Quản trị viên sẽ đối chiếu biên nhận và phản hồi.');
      await loadCases();
    } catch (e: any) {
      setError(e?.message || 'Không thể mở vụ việc.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col pb-24">
      <header className="sticky top-0 z-20 bg-light-surface border-b border-light-outline-variant px-gutter-sm py-gutter-xs flex items-center gap-gutter-xs">
        <button
          type="button"
          onClick={onBack}
          className="inline-flex items-center justify-center w-12 h-12 rounded-full text-light-on-surface hover:bg-light-surface-container"
        >
          <span className="material-symbols-outlined text-[24px]">arrow_back</span>
        </button>
        <h1 className="font-title text-title-lg text-light-on-surface">
          S12 · Báo cáo và vụ việc
        </h1>
      </header>

      <main className="flex-1 flex flex-col gap-gutter-md px-page-margin pt-gutter-md">
        <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
          <h2 className="font-title text-title-md text-light-on-surface">Mở báo cáo mới</h2>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-gutter-sm">
            <div className="flex flex-col gap-1">
              <label className="font-label text-label-md text-light-on-surface">
                Đối tượng báo cáo
              </label>
              <select
                value={targetType}
                onChange={(e) => setTargetType(e.target.value as 'listing' | 'order')}
                className="min-h-[48px] px-3 rounded-md border border-light-outline-variant font-body text-body-md"
              >
                <option value="order">Theo đơn thuê (order)</option>
                <option value="listing">Theo tin đăng (listing)</option>
              </select>
            </div>
            <div className="flex flex-col gap-1">
              <label className="font-label text-label-md text-light-on-surface">
                Mã đơn / Mã tin
              </label>
              <input
                type="text"
                value={targetId}
                onChange={(e) => setTargetId(e.target.value)}
                placeholder="Ví dụ: order-1 hoặc item-1"
                className="min-h-[48px] px-3 rounded-md border border-light-outline-variant font-mono text-body-md"
              />
            </div>
          </div>

          <div className="flex flex-col gap-1">
            <label className="font-label text-label-md text-light-on-surface">
              Lý do báo cáo
            </label>
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="w-full min-h-[48px] px-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md text-light-on-surface"
            >
              <option value="handover">Bất đồng bàn giao (một bên đã ký, chưa nhận được đồ)</option>
              <option value="deposit">Bất đồng tiền cọc</option>
              <option value="accessory">Thiếu phụ kiện kèm theo</option>
              <option value="description">Sai mô tả tin đăng</option>
              <option value="damage">Hư hỏng trong lúc thuê</option>
              <option value="overdue">Quá hạn trả đồ</option>
              <option value="listing_content">Nội dung tin vi phạm</option>
              <option value="other">Lý do khác</option>
            </select>
          </div>

          <div className="flex flex-col gap-1">
            <label className="font-label text-label-md text-light-on-surface">
              Mô tả chi tiết
            </label>
            <textarea
              rows={3}
              value={detail}
              onChange={(e) => setDetail(e.target.value)}
              placeholder="Nêu rõ sự việc để quản trị viên đối chiếu biên nhận và tin nhắn..."
              className="w-full p-3 rounded-md bg-light-surface-container-lowest border border-light-outline-variant font-body text-body-md text-light-on-surface"
            />
          </div>

          {/* Transparent Dispute Rule Box */}
          <div className="rounded-md bg-light-surface-container-low p-gutter-sm flex items-start gap-gutter-sm">
            <span className="material-symbols-outlined text-[18px] text-light-primary mt-0.5 shrink-0">
              lock
            </span>
            <span className="font-body text-body-md text-light-on-surface-variant">
              Quy tắc phân xử minh bạch: Quản trị viên chỉ căn cứ vào (1) Biên nhận & ảnh lúc giao, (2) Biên nhận & ảnh lúc trả, và (3) Tin nhắn trong đơn. Dữ liệu chỉ hiển thị cho hai bên và QTV xử lý.
            </span>
          </div>

          {error && (
            <div className="rounded-md bg-light-error-container text-light-on-error-container p-gutter-sm font-body text-body-md">
              {error}
            </div>
          )}
          {success && (
            <div className="rounded-md bg-success-container text-on-success-container p-gutter-sm font-body text-body-md">
              {success}
            </div>
          )}

          <button
            type="button"
            disabled={busy || !targetId.trim() || !detail.trim()}
            onClick={handleSubmitCase}
            className="w-full inline-flex items-center justify-center min-h-[48px] px-6 py-3 rounded-full bg-light-primary text-light-on-primary hover:bg-light-primary-container font-label text-label-lg disabled:opacity-50"
          >
            Gửi báo cáo vụ việc
          </button>
        </section>

        <section className="flex flex-col gap-gutter-sm">
          <h2 className="font-title text-title-md text-light-on-surface">Vụ việc của tôi</h2>
          {cases.length === 0 ? (
            <div className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md font-body text-body-md text-light-on-surface-variant">
              Bạn chưa có vụ việc nào.
            </div>
          ) : (
            cases.map((c) => (
              <article
                key={c.id}
                className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-xs"
              >
                <div className="flex items-center justify-between gap-gutter-sm">
                  <span className="font-mono text-mono-sm text-light-on-surface-variant tabular-nums">
                    #{c.id} · {c.target_type} #{c.target_id}
                  </span>
                  <span
                    className={`px-2.5 py-0.5 rounded-full font-label text-label-sm ${
                      c.status === 'open'
                        ? 'bg-warning-container text-on-warning-container'
                        : 'bg-success-container text-on-success-container'
                    }`}
                  >
                    {c.status === 'open' ? 'Đang mở' : 'Đã xử lý'}
                  </span>
                </div>
                <h3 className="font-title text-title-md text-light-on-surface">{c.category}</h3>
                <p className="font-body text-body-md text-light-on-surface-variant">{c.detail}</p>
                {c.resolution && (
                  <p className="font-label text-label-md text-light-primary pt-1 border-t border-light-outline-variant">
                    Kết quả từ QTV: {c.resolution}
                  </p>
                )}
              </article>
            ))
          )}
        </section>
      </main>
    </div>
  );
}

interface OwnerFeesScreenProps {
  onBack: () => void;
}

export function OwnerFeesScreen({ onBack }: OwnerFeesScreenProps) {
  const [summary, setSummary] = useState<FeeSummary>({
    accrued: 0,
    settled: 0,
    outstanding: 0,
  });
  const [stateFilter, setStateFilter] = useState<'outstanding' | 'settled'>('outstanding');
  const [entries, setEntries] = useState<FeeEntry[]>([]);
  const [settlements, setSettlements] = useState<Settlement[]>([]);

  const loadFees = async (st = stateFilter) => {
    try {
      const [sum, ent, stl] = await Promise.all([
        api.getFeesSummary(),
        api.getFeeEntries(st),
        api.listSettlements(),
      ]);
      setSummary(sum);
      setEntries(ent.items);
      setSettlements(stl.items);
    } catch {
      // ignore
    }
  };

  useEffect(() => {
    loadFees(stateFilter);
  }, [stateFilter]);

  return (
    <div className="flex flex-col pb-20">
      <header className="sticky top-0 z-20 bg-light-surface border-b border-light-outline-variant px-gutter-sm py-gutter-xs flex items-center gap-gutter-xs">
        <button
          type="button"
          onClick={onBack}
          className="inline-flex items-center justify-center w-12 h-12 rounded-full text-light-on-surface hover:bg-light-surface-container"
        >
          <span className="material-symbols-outlined text-[24px]">arrow_back</span>
        </button>
        <h1 className="font-title text-title-lg text-light-on-surface">
          S13 · Phí và đối soát (Chủ đồ)
        </h1>
      </header>

      <main className="flex-1 flex flex-col gap-gutter-md px-page-margin pt-gutter-md">
        <section className="rounded-lg bg-light-primary text-light-on-primary p-gutter-md flex flex-col gap-gutter-sm">
          <span className="font-label text-label-md text-light-on-primary-container">
            Cần chuyển đối soát tuần này
          </span>
          <span className="font-display text-display-lg-mobile tabular-nums">
            {formatVnd(summary.outstanding)}
          </span>
          <div className="grid grid-cols-2 gap-gutter-sm pt-gutter-xs border-t border-light-primary-container">
            <div className="flex flex-col">
              <span className="font-label text-label-sm text-light-on-primary-container">
                Tổng phí phát sinh
              </span>
              <span className="font-title text-title-md tabular-nums">
                {formatVnd(summary.accrued)}
              </span>
            </div>
            <div className="flex flex-col">
              <span className="font-label text-label-sm text-light-on-primary-container">
                Đã đối soát
              </span>
              <span className="font-title text-title-md tabular-nums">
                {formatVnd(summary.settled)}
              </span>
            </div>
          </div>
        </section>

        <section className="rounded-lg bg-light-surface-container-low border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-xs">
          <h2 className="font-title text-title-md text-light-on-surface">
            Chuyển khoản gộp theo tuần (Cam kết 0đ cho đơn hủy/chưa giao)
          </h2>
          <p className="font-body text-body-md text-light-on-surface-variant">
            Mỗi đơn đã bàn giao thành công (đủ 2 xác nhận giao) mới phát sinh đúng một lần phí: 1.000đ của chủ đồ + 1.000đ thu hộ từ người thuê = 2.000đ/đơn.
          </p>
        </section>

        <div className="flex items-center gap-gutter-xs overflow-x-auto">
          <button
            type="button"
            onClick={() => setStateFilter('outstanding')}
            className={`shrink-0 min-h-[36px] px-3.5 rounded-full font-label text-label-md ${
              stateFilter === 'outstanding'
                ? 'bg-light-secondary-container text-light-on-secondary-container'
                : 'bg-light-surface-container-lowest border border-light-outline-variant text-light-on-surface-variant'
            }`}
          >
            Chưa đối soát
          </button>
          <button
            type="button"
            onClick={() => setStateFilter('settled')}
            className={`shrink-0 min-h-[36px] px-3.5 rounded-full font-label text-label-md ${
              stateFilter === 'settled'
                ? 'bg-light-secondary-container text-light-on-secondary-container'
                : 'bg-light-surface-container-lowest border border-light-outline-variant text-light-on-surface-variant'
            }`}
          >
            Đã đối soát
          </button>
        </div>

        <section className="flex flex-col gap-gutter-sm">
          {entries.length === 0 ? (
            <div className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md font-body text-body-md text-light-on-surface-variant">
              Không có dòng phí nào ở trạng thái này.
            </div>
          ) : (
            entries.map((fe) => (
              <article
                key={fe.order_id}
                className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex items-center justify-between gap-gutter-sm"
              >
                <div className="flex flex-col gap-0.5">
                  <span className="font-title text-title-md text-light-on-surface">
                    Đơn #{fe.order_id}
                  </span>
                  <span className="font-body text-body-md text-light-on-surface-variant tabular-nums">
                    {formatVnd(fe.owner_fee)} chủ đồ + {formatVnd(fe.renter_fee)} thu hộ ·{' '}
                    {formatTimeVN(fe.accrued_at)}
                  </span>
                </div>
                <span className="font-label text-label-lg text-light-primary tabular-nums">
                  {formatVnd(fe.total)}
                </span>
              </article>
            ))
          )}
        </section>

        <section className="rounded-lg bg-light-surface-container-lowest border border-light-outline-variant p-gutter-md flex flex-col gap-gutter-sm">
          <h2 className="font-title text-title-md text-light-on-surface">
            Lịch sử chuyển gộp đã xác nhận
          </h2>
          {settlements.length === 0 ? (
            <span className="font-body text-body-md text-light-on-surface-variant">
              Chưa có đợt đối soát nào được xác nhận.
            </span>
          ) : (
            settlements.map((st) => (
              <div
                key={st.id}
                className="flex items-center justify-between py-gutter-xs border-t border-light-outline-variant"
              >
                <div className="flex flex-col">
                  <span className="font-label text-label-md text-light-on-surface tabular-nums">
                    Đợt {formatTimeVN(st.confirmed_at)} ({st.order_ids.length} đơn)
                  </span>
                  <span className="font-label text-label-sm text-light-on-surface-variant">
                    QTV đã xác nhận · Mã CK #{st.reference}
                  </span>
                </div>
                <span className="font-label text-label-lg text-success tabular-nums">
                  {formatVnd(st.received_amount)}
                </span>
              </div>
            ))
          )}
        </section>
      </main>
    </div>
  );
}
