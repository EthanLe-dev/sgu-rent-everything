import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import 'app_providers.dart';

class OrdersQuery {
  const OrdersQuery({this.roleAs = 'renter', this.status});

  final String roleAs; // renter | owner
  final String? status;

  OrdersQuery copyWith({
    String? roleAs,
    String? status,
    bool clearStatus = false,
  }) =>
      OrdersQuery(
        roleAs: roleAs ?? this.roleAs,
        status: clearStatus ? null : (status ?? this.status),
      );
}

class OrdersListState {
  const OrdersListState({required this.query, required this.items});

  final OrdersQuery query;
  final List<Order> items;
}

class OrdersNotifier extends AsyncNotifier<OrdersListState> {
  OrdersQuery _query = const OrdersQuery();

  @override
  Future<OrdersListState> build() async {
    final me = ref.watch(authProvider).value;
    if (me == null) {
      return OrdersListState(query: _query, items: const []);
    }
    final page = await ref.read(apiClientProvider).getOrders(
          roleAs: _query.roleAs,
          status: _query.status,
        );
    return OrdersListState(query: _query, items: page.items);
  }

  Future<void> setQuery(OrdersQuery next) async {
    _query = next;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(apiClientProvider).getOrders(
            roleAs: _query.roleAs,
            status: _query.status,
          );
      return OrdersListState(query: _query, items: page.items);
    });
  }

  Future<void> refresh() => setQuery(_query);
}

final ordersProvider =
    AsyncNotifierProvider<OrdersNotifier, OrdersListState>(OrdersNotifier.new);
