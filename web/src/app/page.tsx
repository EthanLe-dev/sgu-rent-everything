'use client';

import React, { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import type { Listing, Me, Notice } from '@/lib/types';
import {
  CasesScreen,
  LoginScreen,
  NotificationsScreen,
  OwnerFeesScreen,
  ProfileScreen,
} from '@/components/AccountViews';
import { AdminTab, AdminWorkspace } from '@/components/AdminViews';
import {
  ExploreScreen,
  ListingDetailScreen,
  ListingFormScreen,
  MyListingsScreen,
} from '@/components/ListingViews';
import { OrderDetailScreen, OrdersListScreen } from '@/components/OrderViews';

type ScreenRoute =
  | { name: 'explore' }
  | { name: 'login'; returnTo?: ScreenRoute }
  | { name: 'listing'; id: string }
  | { name: 'post'; editing?: Listing | null }
  | { name: 'my-listings' }
  | { name: 'orders' }
  | { name: 'order'; id: string }
  | { name: 'profile' }
  | { name: 'notifications' }
  | {
      name: 'cases';
      targetType?: 'listing' | 'order';
      targetId?: string;
      category?: string;
    }
  | { name: 'fees' }
  | { name: 'admin'; tab: AdminTab };

function parsePathToRoute(pathname: string): ScreenRoute {
  const clean = pathname.replace(/\/+$/, '') || '/';
  if (clean === '/login') return { name: 'login' };
  if (clean.startsWith('/listings/')) {
    return { name: 'listing', id: clean.replace('/listings/', '') };
  }
  if (clean === '/post') return { name: 'post' };
  if (clean === '/my-listings') return { name: 'my-listings' };
  if (clean === '/orders') return { name: 'orders' };
  if (clean.startsWith('/orders/')) {
    return { name: 'order', id: clean.replace('/orders/', '') };
  }
  if (clean === '/profile') return { name: 'profile' };
  if (clean === '/notifications') return { name: 'notifications' };
  if (clean === '/cases') return { name: 'cases' };
  if (clean === '/fees') return { name: 'fees' };
  if (clean.startsWith('/admin')) {
    if (clean.includes('cases')) return { name: 'admin', tab: 'q02' };
    if (clean.includes('settlements')) return { name: 'admin', tab: 'q03' };
    return { name: 'admin', tab: 'q01' };
  }
  return { name: 'explore' };
}

function routeToPath(r: ScreenRoute): string {
  switch (r.name) {
    case 'explore':
      return '/';
    case 'login':
      return '/login';
    case 'listing':
      return `/listings/${r.id}`;
    case 'post':
      return '/post';
    case 'my-listings':
      return '/my-listings';
    case 'orders':
      return '/orders';
    case 'order':
      return `/orders/${r.id}`;
    case 'profile':
      return '/profile';
    case 'notifications':
      return '/notifications';
    case 'cases':
      return '/cases';
    case 'fees':
      return '/fees';
    case 'admin':
      return r.tab === 'q02'
        ? '/admin/cases'
        : r.tab === 'q03'
        ? '/admin/settlements'
        : '/admin/verifications';
  }
}

export default function HomePage() {
  const [route, setRoute] = useState<ScreenRoute>({ name: 'explore' });
  const [me, setMe] = useState<Me | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [notices, setNotices] = useState<Notice[]>([]);

  // Shared filter date range (defaults to 2-day rental in future so all items are available)
  const [startDate, setStartDate] = useState('2027-03-05');
  const [endDate, setEndDate] = useState('2027-03-06');

  const navigate = (next: ScreenRoute, replace = false) => {
    setRoute(next);
    if (typeof window !== 'undefined') {
      const p = routeToPath(next);
      if (replace) window.history.replaceState(null, '', p);
      else window.history.pushState(null, '', p);
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  };

  const refreshNotices = async () => {
    if (!api.accessToken) {
      setNotices([]);
      return;
    }
    try {
      const page = await api.listNotifications();
      setNotices(page.items);
    } catch {
      // ignore
    }
  };

  useEffect(() => {
    const initial =
      typeof window !== 'undefined'
        ? parsePathToRoute(window.location.pathname)
        : ({ name: 'explore' } as ScreenRoute);

    const onPop = () => {
      setRoute(parsePathToRoute(window.location.pathname));
    };
    window.addEventListener('popstate', onPop);

    const bootstrapAuth = async () => {
      if (api.accessToken) {
        try {
          const user = await api.getMe();
          setMe(user);
          setRoute(initial);
          await refreshNotices();
          setAuthReady(true);
          return;
        } catch {
          api.setAccessToken(null);
        }
      }
      // If deep-linking into a protected route without session, remember destination and show login
      if (initial.name === 'order' || initial.name === 'listing' || initial.name === 'admin') {
        setRoute({ name: 'login', returnTo: initial });
      } else {
        setRoute(initial);
      }
      setAuthReady(true);
    };

    bootstrapAuth();
    return () => window.removeEventListener('popstate', onPop);
  }, []);

  const unreadCount = notices.filter((n) => !n.read_at).length;

  if (!authReady) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-light-surface text-light-on-surface-variant font-body text-body-md">
        Đang khởi tạo Thuê Đồ Sinh Viên...
      </div>
    );
  }

  // Full-screen Admin Workspace (Q01 - Q03)
  if (route.name === 'admin') {
    if (!me || me.role !== 'admin') {
      return (
        <div className="min-h-screen flex flex-col items-center justify-center p-gutter-lg text-center gap-gutter-md">
          <span className="material-symbols-outlined text-[36px] text-light-error">lock</span>
          <h1 className="font-title text-title-lg">Khu vực dành riêng cho Quản trị viên</h1>
          <p className="font-body text-body-md text-light-on-surface-variant">
            Vui lòng đăng nhập bằng tài khoản admin@sgu.test để truy cập Q01–Q03.
          </p>
          <button
            type="button"
            onClick={() => navigate({ name: 'login', returnTo: route })}
            className="min-h-[48px] px-6 rounded-full bg-light-primary text-light-on-primary font-label text-label-lg"
          >
            Đăng nhập Quản trị viên
          </button>
        </div>
      );
    }
    return (
      <AdminWorkspace
        activeTab={route.tab}
        onChangeTab={(tab) => navigate({ name: 'admin', tab })}
        onBackToStudent={() => navigate({ name: 'profile' })}
        onOpenOrder={(orderId) => navigate({ name: 'order', id: orderId })}
      />
    );
  }

  // Standalone S01 Login Screen
  if (route.name === 'login') {
    return (
      <LoginScreen
        onSuccess={async (user) => {
          setMe(user);
          await refreshNotices();
          navigate(route.returnTo || { name: 'explore' }, true);
        }}
        onCancel={() => navigate({ name: 'explore' })}
      />
    );
  }

  const activeNavTab: 'explore' | 'post' | 'orders' | 'profile' =
    route.name === 'post'
      ? 'post'
      : route.name === 'orders' || route.name === 'order'
      ? 'orders'
      : route.name === 'profile' ||
        route.name === 'my-listings' ||
        route.name === 'fees' ||
        route.name === 'cases'
      ? 'profile'
      : 'explore';

  return (
    <div className="min-h-screen w-full flex bg-light-surface">
      {/* Desktop Persistent Left Navigation Rail (≥ 1024px) */}
      <aside
        aria-label="Điều hướng máy tính"
        className="hidden lg:flex w-60 shrink-0 min-h-screen sticky top-0 h-screen bg-light-surface-container-lowest border-r border-light-outline-variant p-gutter-md flex-col justify-between"
      >
        <div className="flex flex-col gap-gutter-lg">
          <button
            type="button"
            onClick={() => navigate({ name: 'explore' })}
            className="flex items-center gap-gutter-sm px-2 text-left"
          >
            <div className="w-9 h-9 rounded-md bg-light-primary text-light-on-primary flex items-center justify-center shrink-0">
              <span className="material-symbols-outlined text-[20px]">school</span>
            </div>
            <div className="flex flex-col">
              <span className="font-title text-title-md text-light-on-surface">
                Thuê Đồ Sinh Viên
              </span>
              <span className="font-label text-label-sm text-light-on-surface-variant">
                Đại học Sài Gòn
              </span>
            </div>
          </button>

          <nav className="flex flex-col gap-gutter-xs">
            {[
              { id: 'explore', label: 'Khám phá', icon: 'explore', target: { name: 'explore' } as ScreenRoute },
              { id: 'post', label: 'Đăng đồ', icon: 'add_box', target: { name: 'post' } as ScreenRoute },
              { id: 'orders', label: 'Giao dịch', icon: 'swap_horiz', target: { name: 'orders' } as ScreenRoute },
              { id: 'profile', label: 'Cá nhân', icon: 'person', target: { name: 'profile' } as ScreenRoute },
            ].map((item) => {
              const selected = activeNavTab === item.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => navigate(item.target)}
                  className={`min-h-[48px] px-4 rounded-full flex items-center gap-gutter-sm font-label text-label-lg transition-colors ${
                    selected
                      ? 'bg-light-secondary-container text-light-on-secondary-container'
                      : 'text-light-on-surface-variant hover:bg-light-surface-container'
                  }`}
                >
                  <span
                    className={`material-symbols-outlined text-[22px] ${
                      selected ? 'material-fill text-light-primary' : ''
                    }`}
                  >
                    {item.icon}
                  </span>
                  <span>{item.label}</span>
                </button>
              );
            })}
          </nav>
        </div>

        <div className="flex flex-col gap-gutter-xs border-t border-light-outline-variant pt-gutter-md">
          {me ? (
            <>
              <div className="px-2 flex flex-col">
                <span className="font-label text-label-md text-light-on-surface truncate">
                  {me.display_name}
                </span>
                <span className="font-label text-label-sm text-light-on-surface-variant truncate">
                  {me.email}
                </span>
              </div>
              {me.role === 'admin' && (
                <button
                  type="button"
                  onClick={() => navigate({ name: 'admin', tab: 'q01' })}
                  className="min-h-[40px] px-3 rounded-full bg-light-tertiary text-light-on-tertiary font-label text-label-sm flex items-center justify-center gap-1"
                >
                  <span className="material-symbols-outlined text-[16px]">
                    admin_panel_settings
                  </span>
                  <span>Mở bảng Quản trị (Q01–Q03)</span>
                </button>
              )}
            </>
          ) : (
            <button
              type="button"
              onClick={() => navigate({ name: 'login' })}
              className="min-h-[44px] px-4 rounded-full bg-light-primary text-light-on-primary font-label text-label-md"
            >
              Đăng nhập OTP
            </button>
          )}
        </div>
      </aside>

      {/* Main Responsive Content Container (Mobile-First 100% width up to 1080px on Desktop) */}
      <div className="flex-1 min-w-0 max-w-[1080px] mx-auto w-full">
        {route.name === 'explore' && (
          <ExploreScreen
            me={me}
            unreadCount={unreadCount}
            startDate={startDate}
            endDate={endDate}
            onChangeDates={(s, e) => {
              setStartDate(s);
              setEndDate(e);
            }}
            onSelectListing={(id) => navigate({ name: 'listing', id })}
            onOpenNotifications={() => {
              refreshNotices();
              navigate({ name: 'notifications' });
            }}
            onOpenLogin={() => navigate({ name: 'login' })}
          />
        )}

        {route.name === 'listing' && (
          <ListingDetailScreen
            listingId={route.id}
            me={me}
            startDate={startDate}
            endDate={endDate}
            onChangeDates={(s, e) => {
              setStartDate(s);
              setEndDate(e);
            }}
            onBack={() => navigate({ name: 'explore' })}
            onEditListing={(listing) => navigate({ name: 'post', editing: listing })}
            onManageSchedule={() => navigate({ name: 'my-listings' })}
            onOrderCreated={(orderId) => {
              refreshNotices();
              navigate({ name: 'order', id: orderId });
            }}
            onReportListing={(listingId) =>
              navigate({
                name: 'cases',
                targetType: 'listing',
                targetId: listingId,
                category: 'description',
              })
            }
            onRequireVerification={() => navigate({ name: 'profile' })}
          />
        )}

        {route.name === 'post' && (
          <ListingFormScreen
            me={me}
            editingListing={route.editing}
            onSaved={(listingId) => navigate({ name: 'listing', id: listingId })}
            onCancel={() => navigate({ name: 'explore' })}
            onRequireVerification={() => navigate({ name: 'profile' })}
          />
        )}

        {route.name === 'my-listings' && (
          <MyListingsScreen
            me={me}
            onBack={() => navigate({ name: 'profile' })}
            onNewListing={() => navigate({ name: 'post' })}
            onEditListing={(listing) => navigate({ name: 'post', editing: listing })}
          />
        )}

        {route.name === 'orders' && (
          <OrdersListScreen
            me={me}
            unreadCount={unreadCount}
            onSelectOrder={(orderId) => navigate({ name: 'order', id: orderId })}
            onOpenNotifications={() => {
              refreshNotices();
              navigate({ name: 'notifications' });
            }}
            onRequireLogin={() => navigate({ name: 'login', returnTo: { name: 'orders' } })}
          />
        )}

        {route.name === 'order' && (
          <OrderDetailScreen
            orderId={route.id}
            me={me}
            onBack={() => navigate({ name: 'orders' })}
            onOpenReport={(orderId, cat) =>
              navigate({
                name: 'cases',
                targetType: 'order',
                targetId: orderId,
                category: cat || 'handover',
              })
            }
          />
        )}

        {route.name === 'profile' && (
          <ProfileScreen
            me={me}
            unreadCount={unreadCount}
            onUpdatedMe={(u) => setMe(u)}
            onLogout={async () => {
              await api.logout();
              setMe(null);
              setNotices([]);
              navigate({ name: 'login' });
            }}
            onOpenLogin={() => navigate({ name: 'login' })}
            onOpenNotifications={() => {
              refreshNotices();
              navigate({ name: 'notifications' });
            }}
            onOpenMyListings={() => navigate({ name: 'my-listings' })}
            onOpenOwnerFees={() => navigate({ name: 'fees' })}
            onOpenCases={() => navigate({ name: 'cases' })}
            onOpenAdmin={() => navigate({ name: 'admin', tab: 'q01' })}
          />
        )}

        {route.name === 'notifications' && (
          <NotificationsScreen
            notices={notices}
            onBack={() => navigate({ name: 'explore' })}
            onSelectNotice={async (n) => {
              if (!n.read_at) {
                try {
                  await api.markNotificationRead(n.id);
                  await refreshNotices();
                } catch {
                  // ignore
                }
              }
              if (n.target_type === 'order') {
                navigate({ name: 'order', id: n.target_id });
              } else {
                navigate({ name: 'cases' });
              }
            }}
            onMarkAllRead={async () => {
              await Promise.all(
                notices.filter((n) => !n.read_at).map((n) => api.markNotificationRead(n.id)),
              );
              await refreshNotices();
            }}
          />
        )}

        {route.name === 'cases' && (
          <CasesScreen
            initialTargetType={route.targetType}
            initialTargetId={route.targetId}
            initialCategory={route.category}
            onBack={() => navigate({ name: 'profile' })}
          />
        )}

        {route.name === 'fees' && (
          <OwnerFeesScreen onBack={() => navigate({ name: 'profile' })} />
        )}
      </div>

      {/* Mobile Bottom Navigation Bar (< 1024px) — Hidden on detail/form screens that have sticky bottom CTA */}
      {(route.name === 'explore' ||
        route.name === 'orders' ||
        route.name === 'profile' ||
        route.name === 'my-listings' ||
        route.name === 'notifications' ||
        route.name === 'cases' ||
        route.name === 'fees') && (
        <nav
          aria-label="Điều hướng chính trên điện thoại"
          className="lg:hidden fixed bottom-0 left-0 right-0 z-30 bg-light-surface-container-lowest border-t border-light-outline-variant px-gutter-sm py-gutter-xs grid grid-cols-4 gap-gutter-xs"
        >
          {[
            { id: 'explore', label: 'Khám phá', icon: 'explore', target: { name: 'explore' } as ScreenRoute },
            { id: 'post', label: 'Đăng đồ', icon: 'add_box', target: { name: 'post' } as ScreenRoute },
            { id: 'orders', label: 'Giao dịch', icon: 'swap_horiz', target: { name: 'orders' } as ScreenRoute },
            { id: 'profile', label: 'Cá nhân', icon: 'person', target: { name: 'profile' } as ScreenRoute },
          ].map((item) => {
            const selected = activeNavTab === item.id;
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => navigate(item.target)}
                className={`flex flex-col items-center justify-center min-h-[56px] gap-gutter-xs ${
                  selected
                    ? 'text-light-primary'
                    : 'text-light-on-surface-variant hover:text-light-on-surface'
                }`}
              >
                <span
                  className={`inline-flex items-center justify-center w-14 h-8 rounded-full ${
                    selected
                      ? 'bg-light-secondary-container text-light-on-secondary-container'
                      : ''
                  }`}
                >
                  <span
                    className={`material-symbols-outlined text-[22px] ${
                      selected ? 'material-fill' : ''
                    }`}
                  >
                    {item.icon}
                  </span>
                </span>
                <span className="font-label text-label-sm">{item.label}</span>
              </button>
            );
          })}
        </nav>
      )}
    </div>
  );
}
