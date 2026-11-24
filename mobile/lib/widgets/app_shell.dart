import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static int _indexForLocation(String loc) {
    if (loc.startsWith('/post')) return 1;
    if (loc.startsWith('/orders')) return 2;
    if (loc.startsWith('/profile') ||
        loc.startsWith('/my-listings') ||
        loc.startsWith('/fees') ||
        loc.startsWith('/cases') ||
        loc.startsWith('/admin')) {
      return 3;
    }
    return 0;
  }

  static void _goTab(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/explore');
      case 1:
        context.go('/post');
      case 2:
        context.go('/orders');
      case 3:
        context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).uri.path;
    final selectedIndex = _indexForLocation(loc);
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final notices = ref.watch(notificationsProvider).value ?? const [];
    final unreadCount = notices.where((n) => n.isUnread).length;
    final cfg = ref.watch(configProvider);

    final destinations = const [
      (icon: Icons.explore_outlined, active: Icons.explore, label: 'Khám phá'),
      (icon: Icons.add_box_outlined, active: Icons.add_box, label: 'Đăng đồ'),
      (icon: Icons.swap_horiz, active: Icons.swap_horiz, label: 'Giao dịch'),
      (icon: Icons.person_outline, active: Icons.person, label: 'Cá nhân'),
    ];

    final notifButton = IconButton(
      tooltip: 'Hộp thông báo',
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text('$unreadCount'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) => _goTab(context, i),
              extended: MediaQuery.sizeOf(context).width >= 1100,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.school,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        if (MediaQuery.sizeOf(context).width >= 1100) ...[
                          const SizedBox(width: 10),
                          Text(
                            'Thuê Đồ Sinh Viên',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (cfg.useMock)
                      const Chip(label: Text('Chế độ mẫu')),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: notifButton,
                  ),
                ),
              ),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.active),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => _goTab(context, i),
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.active),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
