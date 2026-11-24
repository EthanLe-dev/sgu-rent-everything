import type { Order } from './types';

export function formatVnd(amount: number): string {
  const n = Math.trunc(Number(amount) || 0);
  const abs = Math.abs(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return `${n < 0 ? '-' : ''}${abs}đ`;
}

export function calculateRentalDays(startDate: string, endDate: string): number {
  const [sy, sm, sd] = startDate.split('-').map(Number);
  const [ey, em, ed] = endDate.split('-').map(Number);
  if (!sy || !sm || !sd || !ey || !em || !ed) return 1;
  const s = Date.UTC(sy, sm - 1, sd);
  const e = Date.UTC(ey, em - 1, ed);
  if (e < s) return 0;
  return Math.floor((e - s) / 86400000) + 1;
}

export function formatShortDateRange(startDate: string, endDate: string): string {
  const days = calculateRentalDays(startDate, endDate);
  const fmt = (d: string) => {
    const parts = d.split('-');
    return parts.length === 3 ? `${parts[2]}/${parts[1]}` : d;
  };
  return `${fmt(startDate)} – ${fmt(endDate)} (${days} ngày)`;
}

export function formatTimeVN(iso: string): string {
  try {
    const d = new Date(iso);
    return d.toLocaleString('vi-VN', {
      hour: '2-digit',
      minute: '2-digit',
      day: '2-digit',
      month: '2-digit',
    });
  } catch {
    return iso;
  }
}

/**
 * Sinh mã PIN 4 chữ số ổn định từ order.id để hai bên đối chiếu khi gặp trực tiếp tại sân trường.
 */
export function computeHandoverPin(orderId: string): string {
  let hash = 2166136261;
  for (let i = 0; i < orderId.length; i++) {
    hash ^= orderId.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  const pin = (Math.abs(hash) % 9000) + 1000;
  return String(pin);
}

export const SAFE_PICKUP_SPOTS: Record<string, string[]> = {
  'Cơ sở Chính': ['Sảnh Thư viện trung tâm (có camera)', 'Khu tự học dãy C', 'Phòng bảo vệ Cổng chính 273 An Dương Vương'],
  'Cơ sở 1': ['Sảnh khu A (gần bàn trực bảo vệ)', 'Sân sinh hoạt CLB Cơ sở 1'],
  'Cơ sở 2': ['Sảnh nhà A Cơ sở 2 (có camera)', 'Bàn trực bảo vệ cổng chính Cơ sở 2'],
};

export function describeOrderState(order: Order, viewerId?: string): {
  badgeLabel: string;
  tone: 'success' | 'warning' | 'error' | 'secondary';
  icon: string;
  nextStep: string;
} {
  const isOwner = viewerId === order.owner.id;
  if (order.status === 'requested') {
    return {
      badgeLabel: 'Chờ chủ đồ trả lời',
      tone: 'secondary',
      icon: 'schedule',
      nextStep: isOwner ? 'Duyệt hoặc từ chối yêu cầu thuê' : `Chờ ${order.owner.display_name} duyệt yêu cầu`,
    };
  }
  if (order.status === 'approved') {
    if (order.pickup.length === 1) {
      const firstActor = order.pickup[0].actor_id === order.owner.id ? order.owner.display_name : order.renter.display_name;
      const waitingActor = order.pickup[0].actor_id === order.owner.id ? order.renter.display_name : order.owner.display_name;
      return {
        badgeLabel: 'Một bên đã xác nhận giao',
        tone: 'warning',
        icon: 'handshake',
        nextStep: `${firstActor} đã ký biên nhận giao · Chờ ${waitingActor} xác nhận hoặc báo sự cố`,
      };
    }
    return {
      badgeLabel: 'Đã duyệt · Chờ giao',
      tone: 'warning',
      icon: 'handshake',
      nextStep: isOwner
        ? `Hẹn gặp tại ${order.pickup_point}, thu ${formatVnd(order.quote.pickup_total)} và xác nhận giao`
        : `Hẹn gặp tại ${order.pickup_point}, mang ${formatVnd(order.quote.pickup_total)} và xác nhận nhận`,
    };
  }
  if (order.status === 'active') {
    if (order.overdue) {
      return {
        badgeLabel: 'Đang thuê · Quá hạn trả',
        tone: 'error',
        icon: 'warning',
        nextStep: 'Đã quá ngày trả đồ — vui lòng liên hệ trả ngay để mở khóa lượt kế tiếp',
      };
    }
    if (order.returned.length === 1) {
      const waitingActor = order.returned[0].actor_id === order.owner.id ? order.renter.display_name : order.owner.display_name;
      return {
        badgeLabel: 'Một bên đã xác nhận trả',
        tone: 'warning',
        icon: 'assignment_return',
        nextStep: `Đang chờ ${waitingActor} xác nhận đã trả đồ`,
      };
    }
    return {
      badgeLabel: 'Đang thuê',
      tone: 'success',
      icon: 'inventory_2',
      nextStep: `Hạn trả ${order.quote.end_date} · Khi gặp trả đồ, cả hai bên cùng xác nhận`,
    };
  }
  if (order.status === 'returned') {
    if (order.deposit_result.status === 'disputed') {
      return {
        badgeLabel: 'Tranh chấp tiền cọc',
        tone: 'error',
        icon: 'gavel',
        nextStep: 'Hai bên khai số tiền cọc khác nhau — đang chờ Quản trị viên phân xử',
      };
    }
    return {
      badgeLabel: 'Đã trả · Chờ xử lý cọc',
      tone: 'warning',
      icon: 'account_balance_wallet',
      nextStep: 'Mỗi bên nhập số tiền cọc đã hoàn để đối chiếu và hoàn tất đơn',
    };
  }
  if (order.status === 'completed') {
    return {
      badgeLabel: 'Hoàn tất',
      tone: 'success',
      icon: 'check_circle',
      nextStep: order.fee_state === 'outstanding' && isOwner
        ? 'Đơn đã hoàn tất · Còn 2.000đ phí chờ chuyển đối soát tuần'
        : 'Giao dịch đã hoàn tất và chốt tiền cọc',
    };
  }
  if (order.status === 'rejected') {
    return {
      badgeLabel: 'Bị từ chối',
      tone: 'error',
      icon: 'cancel',
      nextStep: order.close_reason === 'schedule_conflict'
        ? 'Đóng tự động do trùng lịch với đơn khác đã được duyệt'
        : `Lý do: ${order.close_reason || 'Chủ đồ từ chối'}`,
    };
  }
  if (order.status === 'cancelled') {
    return {
      badgeLabel: 'Đã hủy',
      tone: 'secondary',
      icon: 'block',
      nextStep: `Đã hủy trước bàn giao (Phí 0đ) · Lý do: ${order.close_reason || 'Hủy đơn'}`,
    };
  }
  return {
    badgeLabel: 'Hết hạn',
    tone: 'secondary',
    icon: 'event_busy',
    nextStep: 'Yêu cầu đã qua ngày thuê mà chưa được duyệt (Phí 0đ)',
  };
}
