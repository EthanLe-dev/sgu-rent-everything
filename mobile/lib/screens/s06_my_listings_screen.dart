import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../models/listing.dart';
import '../state/app_providers.dart';
import '../widgets/auth_image.dart';
import '../widgets/common_ui.dart';

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  List<Listing> _items = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(apiClientProvider).getListings(mine: true);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _openBlocksSheet(Listing item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BlocksSheet(listing: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin của tôi & Lịch bận'),
        actions: [
          IconButton(
            tooltip: 'Đăng tin mới',
            onPressed: () => context.push('/post'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorStateView(error: _error!, onRetry: _load)
              : _items.isEmpty
                  ? EmptyStateView(
                      icon: Icons.inventory_2_outlined,
                      title: 'Bạn chưa đăng món nào',
                      message:
                          'Đăng món đồ ít dùng để chia sẻ cho sinh viên SGU thuê theo ngày.',
                      actionLabel: 'Đăng đồ ngay',
                      onAction: () => context.go('/post'),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final item = _items[i];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 96,
                                    child: AuthImage(
                                      photoId: item.photoIds.isNotEmpty
                                          ? item.photoIds.first
                                          : null,
                                      borderRadius: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${formatVnd(item.dailyRate)}/ngày · ${item.area}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            OutlinedButton(
                                              onPressed: () => context.push(
                                                  '/post?listingId=${item.id}'),
                                              child: const Text('Sửa tin'),
                                            ),
                                            FilledButton.tonal(
                                              onPressed: () =>
                                                  _openBlocksSheet(item),
                                              child: const Text('Khóa lịch'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _BlocksSheet extends ConsumerStatefulWidget {
  const _BlocksSheet({required this.listing});

  final Listing listing;

  @override
  ConsumerState<_BlocksSheet> createState() => _BlocksSheetState();
}

class _BlocksSheetState extends ConsumerState<_BlocksSheet> {
  List<BlockRange> _blocks = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page =
          await ref.read(apiClientProvider).getBlocks(widget.listing.id);
      if (!mounted) return;
      setState(() {
        _blocks = page.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessageFrom(e);
        _loading = false;
      });
    }
  }

  Future<void> _addBlock() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Chọn khoảng ngày bạn cần tự dùng',
      confirmText: 'Khóa lịch',
      cancelText: 'Hủy',
    );
    if (picked == null || !mounted) return;
    setState(() => _error = null);
    try {
      await ref.read(apiClientProvider).createBlock(
            widget.listing.id,
            DateRangeValue(
              startDate: toYmd(picked.start),
              endDate: toYmd(picked.end),
            ),
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageFrom(e));
    }
  }

  Future<void> _deleteBlock(String blockId) async {
    try {
      await ref
          .read(apiClientProvider)
          .deleteBlock(widget.listing.id, blockId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageFrom(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lịch bận: ${widget.listing.title}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: _addBlock,
                icon: const Icon(Icons.add),
                label: const Text('Thêm ngày bận'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            InlineAlertBanner(message: _error!, tone: StatusTone.error),
            const SizedBox(height: 12),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_blocks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Chưa có khoảng ngày tự khóa nào.'),
            )
          else
            for (final b in _blocks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy),
                title: Text(formatDateRangeVi(b.startDate, b.endDate)),
                trailing: IconButton(
                  tooltip: 'Mở lại lịch',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteBlock(b.id),
                ),
              ),
        ],
      ),
    );
  }
}
