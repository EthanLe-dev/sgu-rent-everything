import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/listing.dart';
import 'app_providers.dart';

class ExploreFilter {
  const ExploreFilter({
    this.q = '',
    this.category,
    this.area,
    this.minDailyRate,
    this.maxDailyRate,
    this.startDate,
    this.endDate,
  });

  final String q;
  final String? category;
  final String? area;
  final int? minDailyRate;
  final int? maxDailyRate;
  final String? startDate;
  final String? endDate;

  bool get hasActiveFilters =>
      q.isNotEmpty ||
      category != null ||
      area != null ||
      minDailyRate != null ||
      maxDailyRate != null ||
      (startDate != null && endDate != null);

  ExploreFilter copyWith({
    String? q,
    String? category,
    bool clearCategory = false,
    String? area,
    bool clearArea = false,
    int? minDailyRate,
    bool clearMinRate = false,
    int? maxDailyRate,
    bool clearMaxRate = false,
    String? startDate,
    String? endDate,
    bool clearDates = false,
  }) =>
      ExploreFilter(
        q: q ?? this.q,
        category: clearCategory ? null : (category ?? this.category),
        area: clearArea ? null : (area ?? this.area),
        minDailyRate:
            clearMinRate ? null : (minDailyRate ?? this.minDailyRate),
        maxDailyRate:
            clearMaxRate ? null : (maxDailyRate ?? this.maxDailyRate),
        startDate: clearDates ? null : (startDate ?? this.startDate),
        endDate: clearDates ? null : (endDate ?? this.endDate),
      );
}

class ExploreState {
  const ExploreState({
    required this.filter,
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
  });

  final ExploreFilter filter;
  final List<Listing> items;
  final String? nextCursor;
  final bool isLoadingMore;
}

class ExploreNotifier extends AsyncNotifier<ExploreState> {
  ExploreFilter _filter = const ExploreFilter();

  @override
  Future<ExploreState> build() async {
    ref.watch(apiClientProvider);
    return _fetch(cursor: null);
  }

  Future<ExploreState> _fetch({String? cursor}) async {
    final page = await ref.read(apiClientProvider).getListings(
          q: _filter.q.isEmpty ? null : _filter.q,
          category: _filter.category,
          area: _filter.area,
          minDailyRate: _filter.minDailyRate,
          maxDailyRate: _filter.maxDailyRate,
          startDate: _filter.startDate,
          endDate: _filter.endDate,
          cursor: cursor,
        );
    return ExploreState(
      filter: _filter,
      items: page.items,
      nextCursor: page.nextCursor,
    );
  }

  Future<void> applyFilter(ExploreFilter next) async {
    _filter = next;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }

  Future<void> clearAllFilters() => applyFilter(const ExploreFilter());

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }

  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || cur.nextCursor == null || cur.isLoadingMore) return;
    state = AsyncData(ExploreState(
      filter: cur.filter,
      items: cur.items,
      nextCursor: cur.nextCursor,
      isLoadingMore: true,
    ));
    final nextPage = await _fetch(cursor: cur.nextCursor);
    state = AsyncData(ExploreState(
      filter: _filter,
      items: [...cur.items, ...nextPage.items],
      nextCursor: nextPage.nextCursor,
    ));
  }
}

final exploreProvider =
    AsyncNotifierProvider<ExploreNotifier, ExploreState>(ExploreNotifier.new);
