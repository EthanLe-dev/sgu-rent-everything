import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/q01_admin_verifications_screen.dart';
import 'screens/q02_admin_cases_screen.dart';
import 'screens/q03_admin_settlements_screen.dart';
import 'screens/s01_login_screen.dart';
import 'screens/s02_profile_screen.dart';
import 'screens/s03_explore_screen.dart';
import 'screens/s04_listing_detail_screen.dart';
import 'screens/s05_listing_form_screen.dart';
import 'screens/s06_my_listings_screen.dart';
import 'screens/s07_orders_screen.dart';
import 'screens/s08_order_detail_screen.dart';
import 'screens/s11_notifications_screen.dart';
import 'screens/s12_cases_screen.dart';
import 'screens/s13_owner_fees_screen.dart';
import 'state/app_providers.dart';
import 'widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/explore',
    redirect: (context, state) {
      final me = ref.read(authProvider).value;
      final path = state.uri.path;
      final needsAuth = path.startsWith('/orders/') ||
          path.startsWith('/my-listings') ||
          path.startsWith('/fees') ||
          path.startsWith('/cases') ||
          path.startsWith('/notifications') ||
          path.startsWith('/admin');
      if (me == null && needsAuth) {
        final target = Uri.encodeComponent(state.uri.toString());
        return '/login?redirect=$target';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          redirectTo: state.uri.queryParameters['redirect'],
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/explore',
            builder: (context, state) => const ExploreScreen(),
          ),
          GoRoute(
            path: '/listings/:id',
            builder: (context, state) => ListingDetailScreen(
              listingId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/post',
            builder: (context, state) => ListingFormScreen(
              listingId: state.uri.queryParameters['listingId'],
            ),
          ),
          GoRoute(
            path: '/my-listings',
            builder: (context, state) => const MyListingsScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/orders/:id',
            builder: (context, state) => OrderDetailScreen(
              orderId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/fees',
            builder: (context, state) => const OwnerFeesScreen(),
          ),
          GoRoute(
            path: '/cases',
            builder: (context, state) => const CasesScreen(),
          ),
          GoRoute(
            path: '/cases/new',
            builder: (context, state) => ReportCaseScreen(
              targetType: state.uri.queryParameters['targetType'] ?? 'order',
              targetId: state.uri.queryParameters['targetId'] ?? '',
              initialCategory: state.uri.queryParameters['category'],
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/admin/verifications',
            builder: (context, state) => const AdminVerificationsScreen(),
          ),
          GoRoute(
            path: '/admin/cases',
            builder: (context, state) => const AdminCasesScreen(),
          ),
          GoRoute(
            path: '/admin/settlements',
            builder: (context, state) => const AdminSettlementsScreen(),
          ),
        ],
      ),
    ],
  );
});
