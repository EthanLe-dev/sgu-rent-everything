import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../state/app_providers.dart';
import '../state/explore_provider.dart';
import '../widgets/auth_image.dart';
import '../widgets/common_ui.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDates(ExploreFilter current) async {
    final now = DateTime.now();
    final initialStart = parseYmd(current.startDate) ?? now;
    final initialEnd =
        parseYmd(current.endDate) ?? now.add(const Duration(days: 1));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Chọn khoảng ngày nhận – trả',
      confirmText: 'Áp dụng',
      cancelText: 'Hủy',
    );
    if (picked == null || !mounted) return;
    await ref.read(exploreProvider.notifier).applyFilter(
          current.copyWith(
            startDate: toYmd(picked.start),
            endDate: toYmd(picked.end),
          ),
        );
  }

  Future<void> _openFilterSheet(ExploreFilter current) async {
    final catalog = await ref.read(catalogOptionsProvider.future);
    if (!mounted) return;
    String? selectedCat = current.category;
    final maxCtrl = TextEditingController(
      text: current.maxDailyRate?.toString() ?? '',
    );

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Bộ lọc nâng cao',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: selectedCat,
                decoration: const InputDecoration(labelText: 'Loại đồ'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tất cả loại')),
                  for (final c in catalog.categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setModalState(() => selectedCat = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Giá tối đa mỗi ngày (VND)',
                  hintText: 'Ví dụ: 100000',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        selectedCat = null;
                        maxCtrl.clear();
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Xóa lọc'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Áp dụng'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (applied == true && mounted) {
      final maxPrice = int.tryParse(maxCtrl.text.trim());
      await ref.read(exploreProvider.notifier).applyFilter(
            current.copyWith(
              category: selectedCat,
              clearCategory: selectedCat == null,
              maxDailyRate: maxPrice,
              clearMaxRate: maxPrice == null,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final exploreAsync = ref.watch(exploreProvider);
    final notices = ref.watch(notificationsProvider).value ?? const [];
    final unread = notices.where((n) => n.isUnread).length;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thuê Đồ Sinh Viên', style: tt.titleMedium),
                Text(
                  'Đại học Sài Gòn',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Hộp thông báo',
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      body: exploreAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(
          error: e,
          onRetry: () => ref.read(exploreProvider.notifier).refresh(),
        ),
        data: (state) {
          final filter = state.filter;
          final items = state.items;
          const areas = ['Cơ sở 1', 'Cơ sở 2', 'Cơ sở Chính'];

          return RefreshIndicator(
            onRefresh: () => ref.read(exploreProvider.notifier).refresh(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _searchCtrl,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (v) => ref
                              .read(exploreProvider.notifier)
                              .applyFilter(filter.copyWith(q: v.trim())),
                          decoration: InputDecoration(
                            hintText: 'Tìm máy ảnh, máy tính, áo dài...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              tooltip: 'Bộ lọc nâng cao',
                              icon: const Icon(Icons.tune),
                              onPressed: () => _openFilterSheet(filter),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              InputChip(
                                avatar: const Icon(Icons.calendar_today, size: 16),
                                label: Text(
                                  (filter.startDate != null &&
                                          filter.endDate != null)
                                      ? formatDateRangeVi(
                                          filter.startDate!, filter.endDate!)
                                      : 'Chọn ngày nhận – trả',
                                ),
                                selected: filter.startDate != null,
                                onPressed: () => _pickDates(filter),
                                onDeleted: filter.startDate != null
                                    ? () => ref
                                        .read(exploreProvider.notifier)
                                        .applyFilter(
                                            filter.copyWith(clearDates: true))
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Dưới 50.000đ'),
                                selected: filter.maxDailyRate == 50000,
                                onSelected: (sel) => ref
                                    .read(exploreProvider.notifier)
                                    .applyFilter(
                                      filter.copyWith(
                                        maxDailyRate: sel ? 50000 : null,
                                        clearMaxRate: !sel,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('Tất cả cơ sở'),
                                selected: filter.area == null,
                                onSelected: (_) => ref
                                    .read(exploreProvider.notifier)
                                    .applyFilter(
                                        filter.copyWith(clearArea: true)),
                              ),
                              for (final a in areas) ...[
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: Text(a),
                                  selected: filter.area == a,
                                  onSelected: (sel) => ref
                                      .read(exploreProvider.notifier)
                                      .applyFilter(
                                        filter.copyWith(
                                          area: sel ? a : null,
                                          clearArea: !sel,
                                        ),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              filter.startDate != null
                                  ? 'Món trống toàn khoảng ngày'
                                  : 'Món đồ sẵn sàng cho thuê',
                              style: tt.titleMedium,
                            ),
                            Text(
                              '${items.length} món',
                              style: tt.labelLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontFeatures: AppTheme.tabular,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      icon: Icons.search_off,
                      title: 'Không có món trống theo bộ lọc này',
                      message:
                          'Thử đổi khoảng ngày thuê hoặc xóa bớt bộ lọc để xem thêm đồ.',
                      actionLabel: 'Đổi ngày',
                      onAction: () => _pickDates(filter),
                      secondaryLabel: 'Xóa bộ lọc',
                      onSecondaryAction: () {
                        _searchCtrl.clear();
                        ref.read(exploreProvider.notifier).clearAllFilters();
                      },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.crossAxisExtent;
                        final cols = w >= 1000 ? 4 : (w >= 620 ? 3 : 2);
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final item = items[i];
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () =>
                                      context.push('/listings/${item.id}'),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AuthImage(
                                          photoId: item.photoIds.isNotEmpty
                                              ? item.photoIds.first
                                              : null,
                                          borderRadius: 10,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: tt.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${formatVnd(item.dailyRate)}/ngày',
                                          style: tt.labelLarge?.copyWith(
                                            color: cs.primary,
                                            fontFeatures: AppTheme.tabular,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 14,
                                              color: cs.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                item.area,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: tt.labelSmall?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: items.length,
                          ),
                        );
                      },
                    ),
                  ),
                if (state.nextCursor != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Center(
                        child: OutlinedButton(
                          onPressed: state.isLoadingMore
                              ? null
                              : () => ref
                                  .read(exploreProvider.notifier)
                                  .loadMore(),
                          child: Text(
                            state.isLoadingMore
                                ? 'Đang tải...'
                                : 'Tải thêm món trống',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
