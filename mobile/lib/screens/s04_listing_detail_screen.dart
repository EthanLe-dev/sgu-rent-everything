import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../models/api_error.dart';
import '../models/listing.dart';
import '../state/app_providers.dart';
import '../state/orders_provider.dart';
import '../widgets/auth_image.dart';
import '../widgets/common_ui.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  Listing? _listing;
  List<DateRangeValue> _unavailable = const [];
  Quote? _quote;
  bool _loading = true;
  Object? _loadError;

  String? _startDate;
  String? _endDate;
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  String? _actionError;
  String? _pendingIdempKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final l = await api.getListing(widget.listingId);
      final now = DateTime.now();
      final busy = await api.getAvailability(
        widget.listingId,
        startDate: toYmd(now),
        endDate: toYmd(now.add(const Duration(days: 60))),
      );
      if (!mounted) return;
      setState(() {
        _listing = l;
        _unavailable = busy;
        _loading = false;
      });
      if (_startDate != null && _endDate != null) {
        await _refreshQuote();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: DateTimeRange(
        start: parseYmd(_startDate) ?? now.add(const Duration(days: 1)),
        end: parseYmd(_endDate) ?? now.add(const Duration(days: 2)),
      ),
      helpText: 'Chọn ngày nhận và trả đồ',
      confirmText: 'Xem báo giá',
      cancelText: 'Hủy',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = toYmd(picked.start);
      _endDate = toYmd(picked.end);
      _actionError = null;
      _pendingIdempKey = null;
    });
    await _refreshQuote();
  }

  Future<void> _refreshQuote() async {
    if (_startDate == null || _endDate == null) return;
    try {
      final q = await ref.read(apiClientProvider).quoteListing(
            widget.listingId,
            DateRangeValue(startDate: _startDate!, endDate: _endDate!),
          );
      if (!mounted) return;
      setState(() {
        _quote = q;
        _actionError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = errorMessageFrom(e));
    }
  }

  Future<void> _submitOrder() async {
    final me = ref.read(authProvider).value;
    if (me == null) {
      context.go('/login?redirect=/listings/${widget.listingId}');
      return;
    }
    if (!me.isApproved) {
      context.go('/profile');
      return;
    }
    final q = _quote;
    if (q == null) return;

    _pendingIdempKey ??= newUuidV4();
    setState(() {
      _submitting = true;
      _actionError = null;
    });

    try {
      final order = await ref.read(apiClientProvider).createOrder(
            listingId: q.listingId,
            listingRevision: q.listingRevision,
            startDate: q.startDate,
            endDate: q.endDate,
            note: _noteCtrl.text.trim(),
            idempotencyKey: _pendingIdempKey,
          );
      _pendingIdempKey = null;
      ref.invalidate(ordersProvider);
      if (!mounted) return;
      context.go('/orders/${order.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'quote_changed') {
        _pendingIdempKey = null;
        await _load();
      }
      setState(() => _actionError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = errorMessageFrom(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).value;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết món'),
        actions: [
          if (_listing != null)
            IconButton(
              tooltip: 'Báo cáo tin đăng',
              onPressed: () => context.push(
                '/cases/new?targetType=listing&targetId=${_listing!.id}',
              ),
              icon: const Icon(Icons.flag_outlined),
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _loadError != null
              ? ErrorStateView(error: _loadError!, onRetry: _load)
              : _buildBody(context, me, cs, tt),
    );
  }

  Widget _buildBody(
    BuildContext context,
    dynamic me,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final item = _listing!;
    final isOwner = me != null && me.id == item.owner.id;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AuthImage(
            photoId: item.photoIds.isNotEmpty ? item.photoIds.first : null,
            borderRadius: 16,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: tt.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      '${item.category} · ${item.pickupPoint}',
                      style:
                          tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${formatVnd(item.dailyRate)}/ngày',
                    style: tt.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    item.deposit == 0
                        ? 'Không yêu cầu cọc'
                        : 'Cọc ${formatVnd(item.deposit)}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(item.owner.displayName),
              subtitle: Text(
                item.owner.verified
                    ? 'Sinh viên đã xác minh'
                    : 'Chủ đồ tại ${item.area}',
              ),
              trailing: item.owner.verified
                  ? const StatusBadge(
                      label: 'Đã xác minh',
                      icon: Icons.verified,
                      tone: StatusTone.success,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mô tả & Tình trạng', style: tt.titleSmall),
                  const SizedBox(height: 6),
                  Text(item.description),
                  const SizedBox(height: 8),
                  Text(
                    'Tình trạng: ${item.condition}',
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (item.accessories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Phụ kiện đi kèm', style: tt.titleSmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final a in item.accessories) Chip(label: Text(a)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lịch bận công khai', style: tt.titleSmall),
                  const SizedBox(height: 6),
                  if (_unavailable.isEmpty)
                    Text(
                      'Hiện chưa có ngày bận trong 60 ngày tới.',
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final r in _unavailable)
                          Chip(
                            avatar: const Icon(Icons.event_busy, size: 16),
                            label: Text(
                              formatDateRangeVi(r.startDate, r.endDate),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isOwner) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.push('/post?listingId=${item.id}'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Sửa tin'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/my-listings'),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Quản lý lịch'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Tính báo giá & Đặt thuê', style: tt.titleMedium),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _startDate != null && _endDate != null
                            ? formatDateRangeVi(_startDate!, _endDate!)
                            : 'Chọn ngày nhận – ngày trả',
                      ),
                    ),
                    if (_actionError != null) ...[
                      const SizedBox(height: 12),
                      InlineAlertBanner(
                        message: _actionError!,
                        tone: StatusTone.error,
                      ),
                    ],
                    if (_quote != null) ...[
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 10),
                      MoneyRow(
                        label:
                            'Tiền thuê (${formatVnd(_quote!.dailyRate)} × ${_quote!.days} ngày)',
                        amount: _quote!.rent,
                      ),
                      MoneyRow(
                        label: 'Phí dự kiến của người thuê',
                        subtitle:
                            'Chỉ phát sinh sau khi đủ hai xác nhận giao',
                        amount: _quote!.renterFee,
                      ),
                      MoneyRow(
                        label: 'Tiền cọc có thể hoàn',
                        amount: _quote!.deposit,
                      ),
                      const Divider(),
                      MoneyRow(
                        label: 'Cần mang khi nhận máy',
                        amount: _quote!.pickupTotal,
                        emphasize: true,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Lời nhắn hẹn giờ / vị trí (tùy chọn)',
                          hintText: 'Ví dụ: Mình hẹn ở sảnh A lúc 9h nhé.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (me != null && !me.isApproved) ...[
                        InlineAlertBanner(
                          message:
                              'Tài khoản cần được duyệt sinh viên trước khi gửi yêu cầu thuê.',
                          tone: StatusTone.warning,
                          actionLabel: 'Xác minh',
                          onAction: () => context.go('/profile'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      FilledButton(
                        onPressed: _submitting ? null : _submitOrder,
                        child: Text(
                          _submitting
                              ? 'Đang gửi yêu cầu...'
                              : me == null
                                  ? 'Đăng nhập để gửi yêu cầu thuê'
                                  : 'Gửi yêu cầu thuê',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
