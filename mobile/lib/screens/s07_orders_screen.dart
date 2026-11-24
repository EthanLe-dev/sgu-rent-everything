import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/order.dart';
import '../state/app_providers.dart';
import '../state/orders_provider.dart';
import '../widgets/common_ui.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).value;
    if (me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Giao dịch')),
        body: EmptyStateView(
          icon: Icons.swap_horiz,
          title: 'Đăng nhập để xem giao dịch',
          message:
              'Theo dõi đơn thuê, lịch giao trả, trao đổi theo đơn và tiền cọc.',
          actionLabel: 'Đăng nhập',
          onAction: () => context.go('/login?redirect=/orders'),
        ),
      );
    }

    final ordersAsync = ref.watch(ordersProvider);
    const statuses = <(String?, String)>[
      (null, 'Tất cả'),
      ('requested', 'Chờ duyệt'),
      ('approved', 'Chờ giao'),
      ('active', 'Đang thuê'),
      ('returned', 'Chờ cọc'),
      ('completed', 'Hoàn tất'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch'),
        actions: [
          IconButton(
            tooltip: 'Hộp thông báo',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(
          error: e,
          onRetry: () => ref.read(ordersProvider.notifier).refresh(),
        ),
        data: (state) {
          final query = state.query;
          final items = state.items;

          return RefreshIndicator(
            onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'renter',
                      label: Text('Tôi đi thuê'),
                      icon: Icon(Icons.shopping_bag_outlined),
                    ),
                    ButtonSegment(
                      value: 'owner',
                      label: Text('Tôi cho thuê'),
                      icon: Icon(Icons.storefront_outlined),
                    ),
                  ],
                  selected: {query.roleAs},
                  onSelectionChanged: (sel) => ref
                      .read(ordersProvider.notifier)
                      .setQuery(query.copyWith(roleAs: sel.first)),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (code, label) in statuses) ...[
                        FilterChip(
                          label: Text(label),
                          selected: query.status == code,
                          onSelected: (_) => ref
                              .read(ordersProvider.notifier)
                              .setQuery(
                                query.copyWith(
                                  status: code,
                                  clearStatus: code == null,
                                ),
                              ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  EmptyStateView(
                    icon: Icons.inbox_outlined,
                    title: 'Chưa có yêu cầu thuê',
                    message: query.roleAs == 'renter'
                        ? 'Khám phá món đồ quanh cơ sở để gửi yêu cầu thuê đầu tiên.'
                        : 'Khi có sinh viên đặt thuê đồ của bạn, đơn sẽ hiện tại đây.',
                    actionLabel:
                        query.roleAs == 'renter' ? 'Khám phá ngay' : null,
                    onAction: query.roleAs == 'renter'
                        ? () => context.go('/explore')
                        : null,
                  )
                else
                  for (final o in items) ...[
                    _OrderCard(order: o, roleAs: query.roleAs),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.roleAs});

  final Order order;
  final String roleAs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final partner = roleAs == 'owner' ? order.renter : order.owner;

    final (icon, tone) = switch (order.status) {
      'completed' => (Icons.check_circle_outline, StatusTone.success),
      'active' => order.overdue
          ? (Icons.warning_amber_rounded, StatusTone.error)
          : (Icons.timelapse, StatusTone.info),
      'approved' => (Icons.handshake_outlined, StatusTone.warning),
      'returned' => (Icons.savings_outlined, StatusTone.warning),
      'cancelled' || 'rejected' || 'expired' => (
          Icons.cancel_outlined,
          StatusTone.neutral,
        ),
      _ => (Icons.hourglass_empty, StatusTone.info),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(order.title, style: tt.titleMedium),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: order.displayStatusVi,
                    icon: icon,
                    tone: tone,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${roleAs == 'owner' ? 'Người thuê' : 'Chủ đồ'}: ${partner.displayName} · ${order.pickupPoint}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                formatDateRangeVi(
                  order.quote.startDate,
                  order.quote.endDate,
                ),
                style: tt.bodyMedium?.copyWith(fontFeatures: AppTheme.tabular),
              ),
              if (order.blockingOrderId != null) ...[
                const SizedBox(height: 8),
                InlineAlertBanner(
                  message:
                      'Món đang ở lượt thuê khác (${order.blockingOrderId}). Cần nhận lại trước khi giao lượt này.',
                  tone: StatusTone.warning,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    roleAs == 'owner'
                        ? 'Thu lúc giao: ${formatVnd(order.quote.pickupTotal)}'
                        : 'Cần mang: ${formatVnd(order.quote.pickupTotal)}',
                    style: tt.labelLarge?.copyWith(
                      color: cs.primary,
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
