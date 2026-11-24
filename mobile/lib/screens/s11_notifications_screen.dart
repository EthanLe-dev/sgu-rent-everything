import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../state/app_providers.dart';
import '../widgets/common_ui.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).value;
    if (me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thông báo')),
        body: EmptyStateView(
          icon: Icons.notifications_none,
          title: 'Đăng nhập để xem thông báo',
          message: 'Thông báo về đơn thuê, lịch giao trả và vụ việc sẽ hiện tại đây.',
          actionLabel: 'Đăng nhập',
          onAction: () => context.go('/login?redirect=/notifications'),
        ),
      );
    }

    final noticesAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Hộp thông báo')),
      body: noticesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(
          error: e,
          onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateView(
              icon: Icons.notifications_none,
              title: 'Chưa có thông báo nào',
              message: 'Các cập nhật về đơn thuê và vụ việc sẽ hiện ở đây.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = items[i];
                return Card(
                  color: n.isUnread
                      ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4)
                      : null,
                  child: ListTile(
                    leading: Icon(
                      n.isUnread
                          ? Icons.mark_email_unread_outlined
                          : Icons.drafts_outlined,
                    ),
                    title: Text(n.title),
                    subtitle: Text(
                      '${n.body}\n${formatTimestampVi(n.createdAt)}',
                    ),
                    isThreeLine: true,
                    onTap: () async {
                      if (n.isUnread) {
                        await ref
                            .read(notificationsProvider.notifier)
                            .markRead(n.id);
                      }
                      if (!context.mounted) return;
                      if (n.targetType == 'order') {
                        context.push('/orders/${n.targetId}');
                      } else {
                        context.push('/cases');
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
