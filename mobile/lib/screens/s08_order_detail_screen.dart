import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../models/api_error.dart';
import '../models/order.dart';
import '../state/app_providers.dart';
import '../state/orders_provider.dart';
import '../widgets/auth_image.dart';
import '../widgets/common_ui.dart';
import 's09_handover_sheet.dart';
import 's10_deposit_dialog.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Order? _order;
  List<OrderMessage> _messages = const [];
  bool _loading = true;
  Object? _loadError;
  String? _actionError;
  bool _busy = false;
  final _msgCtrl = TextEditingController();
  final Map<String, String> _failedMsgKeys = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final o = await api.getOrder(widget.orderId);
      final msgs = await api.getOrderMessages(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = o;
        _messages = msgs.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  Future<void> _runOrderAction(Future<Order> Function() call) async {
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final updated = await call();
      ref.invalidate(ordersProvider);
      if (!mounted) return;
      setState(() => _order = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e.message);
      if (e.statusCode == 409) await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = errorMessageFrom(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askReason(String title, String hint) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: InputDecoration(labelText: 'Lý do', hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> _openHandover(bool isPickup) async {
    final updated = await showModalBottomSheet<Order>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HandoverSheet(order: _order!, isPickup: isPickup),
    );
    if (updated != null && mounted) {
      ref.invalidate(ordersProvider);
      setState(() => _order = updated);
    }
  }

  Future<void> _openDeposit() async {
    final updated = await showDialog<Order>(
      context: context,
      builder: (_) => DepositDialog(order: _order!),
    );
    if (updated != null && mounted) {
      ref.invalidate(ordersProvider);
      setState(() => _order = updated);
    }
  }

  Future<void> _sendMessage({String? retryText, String? retryLocalId}) async {
    final text = (retryText ?? _msgCtrl.text).trim();
    if (text.isEmpty) return;
    if (retryText == null) _msgCtrl.clear();

    final localId = retryLocalId ?? 'local-${newUuidV4()}';
    final idempKey = _failedMsgKeys[localId] ?? newUuidV4();
    final me = ref.read(authProvider).value;

    setState(() {
      _messages = [
        ..._messages.where((m) => m.id != localId),
        OrderMessage(
          id: localId,
          orderId: widget.orderId,
          senderId: me?.id ?? '',
          text: text,
          createdAt: DateTime.now().toUtc().toIso8601String(),
          isPending: true,
        ),
      ];
    });

    try {
      final sent = await ref.read(apiClientProvider).sendOrderMessage(
            widget.orderId,
            text: text,
            idempotencyKey: idempKey,
          );
      _failedMsgKeys.remove(localId);
      if (!mounted) return;
      setState(() {
        _messages = [
          for (final m in _messages) m.id == localId ? sent : m,
        ];
      });
    } catch (_) {
      _failedMsgKeys[localId] = idempKey;
      if (!mounted) return;
      setState(() {
        _messages = [
          for (final m in _messages)
            if (m.id == localId)
              OrderMessage(
                id: localId,
                orderId: widget.orderId,
                senderId: m.senderId,
                text: m.text,
                createdAt: m.createdAt,
                isFailed: true,
              )
            else
              m,
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn'),
        actions: [
          if (_order != null && _order!.can('report'))
            IconButton(
              tooltip: 'Báo sự cố',
              onPressed: () {
                final isHandover =
                    _order!.status == 'approved' && _order!.pickup.length == 1;
                final cat = isHandover ? '&category=handover' : '';
                context.push(
                  '/cases/new?targetType=order&targetId=${_order!.id}$cat',
                );
              },
              icon: const Icon(Icons.report_problem_outlined),
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _loadError != null
              ? EmptyStateView(
                  icon: Icons.lock_outline,
                  title: 'Không thể truy cập đơn này',
                  message: errorMessageFrom(_loadError!),
                  actionLabel: 'Quay lại Giao dịch',
                  onAction: () => context.go('/orders'),
                )
              : _buildBody(context, me?.id ?? ''),
    );
  }

  Widget _buildBody(BuildContext context, String myId) {
    final o = _order!;
    final isOwner = myId == o.owner.id;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(o.title, style: tt.titleLarge)),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: o.displayStatusVi,
                        icon: o.overdue
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline,
                        tone: o.overdue
                            ? StatusTone.error
                            : o.status == 'completed'
                                ? StatusTone.success
                                : StatusTone.info,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${formatDateRangeVi(o.quote.startDate, o.quote.endDate)} · ${o.pickupPoint}',
                    style: tt.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOwner
                        ? 'Người thuê: ${o.renter.displayName}'
                        : 'Chủ đồ: ${o.owner.displayName}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (o.closeReason != null) ...[
                    const SizedBox(height: 8),
                    InlineAlertBanner(
                      message: 'Lý do đóng đơn: ${o.closeReason}',
                      tone: StatusTone.neutral,
                    ),
                  ],
                  if (o.blockingOrderId != null) ...[
                    const SizedBox(height: 8),
                    InlineAlertBanner(
                      message:
                          'Món đang được giữ ở đơn ${o.blockingOrderId}. Cần xác nhận trả đơn đó trước khi giao lượt này.',
                      tone: StatusTone.warning,
                    ),
                  ],
                  if (_actionError != null) ...[
                    const SizedBox(height: 10),
                    InlineAlertBanner(
                      message: _actionError!,
                      tone: StatusTone.error,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _buildActions(o),
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
                  Text('Chi tiết tiền & Phí', style: tt.titleMedium),
                  const SizedBox(height: 8),
                  MoneyRow(
                    label:
                        'Tiền thuê (${formatVnd(o.quote.dailyRate)} × ${o.quote.days} ngày)',
                    amount: o.quote.rent,
                  ),
                  MoneyRow(
                    label: isOwner
                        ? (o.feeState == 'unaccrued'
                            ? 'Phí dự kiến của chủ đồ'
                            : 'Phí chủ đồ (${o.feeState == 'settled' ? 'đã đối soát' : 'chờ đối soát'})')
                        : (o.feeState == 'unaccrued'
                            ? 'Phí dự kiến của người thuê'
                            : 'Phí người thuê (đã ghi nhận)'),
                    amount: isOwner ? o.quote.ownerFee : o.quote.renterFee,
                  ),
                  MoneyRow(label: 'Tiền cọc', amount: o.quote.deposit),
                  const Divider(),
                  if (isOwner) ...[
                    MoneyRow(
                      label: 'Thu lúc giao (gồm cọc)',
                      amount: o.quote.pickupTotal,
                    ),
                    MoneyRow(
                      label: 'Tiền thuê thực nhận',
                      amount: o.quote.ownerNet,
                      emphasize: true,
                    ),
                  ] else ...[
                    MoneyRow(
                      label: o.status == 'completed' &&
                              o.depositResult.refunded == o.quote.deposit
                          ? 'Chi phí thuê thực tế'
                          : 'Cần mang khi nhận máy',
                      amount: o.status == 'completed' &&
                              o.depositResult.refunded == o.quote.deposit
                          ? o.quote.rent + o.quote.renterFee
                          : o.quote.pickupTotal,
                      emphasize: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ReceiptsCard(
            title: 'Biên nhận giao đồ (${o.pickup.length}/2)',
            receipts: o.pickup,
            ownerId: o.owner.id,
          ),
          const SizedBox(height: 12),
          _ReceiptsCard(
            title: 'Biên nhận trả đồ (${o.returned.length}/2)',
            receipts: o.returned,
            ownerId: o.owner.id,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tiền cọc', style: tt.titleMedium),
                      StatusBadge(
                        label: o.depositResult.labelVi,
                        icon: Icons.savings_outlined,
                        tone: o.depositResult.status == 'disputed'
                            ? StatusTone.error
                            : (o.depositResult.status == 'agreed' ||
                                    o.depositResult.status == 'resolved')
                                ? StatusTone.success
                                : StatusTone.neutral,
                      ),
                    ],
                  ),
                  if (o.depositResult.refunded != null) ...[
                    const SizedBox(height: 8),
                    MoneyRow(
                      label: 'Số tiền cọc hoàn lại',
                      amount: o.depositResult.refunded!,
                      emphasize: true,
                    ),
                  ],
                  if (o.depositResult.reason != null) ...[
                    const SizedBox(height: 4),
                    Text('Ghi chú: ${o.depositResult.reason}'),
                  ],
                  for (final c in o.depositResult.claims)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${c.actorId == o.owner.id ? 'Chủ đồ' : 'Người thuê'} khai hoàn ${formatVnd(c.refunded)}${c.reason != null ? ' · ${c.reason}' : ''}',
                        style: tt.bodySmall,
                      ),
                    ),
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
                  Text('Trao đổi theo đơn', style: tt.titleMedium),
                  const SizedBox(height: 8),
                  if (_messages.isEmpty)
                    Text(
                      'Chưa có tin nhắn. Hai bên chốt giờ và vị trí gặp tại ${o.pickupPoint} tại đây.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    )
                  else
                    for (final m in _messages)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: m.senderId == myId
                              ? cs.secondaryContainer
                              : cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.text),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${m.senderId == o.owner.id ? o.owner.displayName : o.renter.displayName} · ${formatTimestampVi(m.createdAt)}',
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                if (m.isFailed)
                                  TextButton(
                                    onPressed: () => _sendMessage(
                                      retryText: m.text,
                                      retryLocalId: m.id,
                                    ),
                                    child: const Text('Gửi lại'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  if (o.can('message')) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Nhắn giờ hẹn, vị trí cụ thể...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Gửi tin nhắn',
                          onPressed: () => _sendMessage(),
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActions(Order o) {
    final buttons = <Widget>[];
    if (o.can('approve')) {
      buttons.add(FilledButton(
        onPressed: _busy
            ? null
            : () => _runOrderAction(
                () => ref.read(apiClientProvider).approveOrder(o.id)),
        child: const Text('Duyệt yêu cầu'),
      ));
    }
    if (o.can('reject')) {
      buttons.add(OutlinedButton(
        onPressed: _busy
            ? null
            : () async {
                final r = await _askReason(
                    'Từ chối yêu cầu', 'Ví dụ: Mình cần dùng máy hôm đó');
                if (r != null) {
                  await _runOrderAction(() => ref
                      .read(apiClientProvider)
                      .rejectOrder(o.id, reason: r));
                }
              },
        child: const Text('Từ chối'),
      ));
    }
    if (o.can('pickup')) {
      buttons.add(FilledButton(
        onPressed: _busy ? null : () => _openHandover(true),
        child: Text(
          o.pickup.isEmpty
              ? 'Xác nhận giao / nhận đồ'
              : 'Xác nhận nốt phần giao đồ',
        ),
      ));
    }
    if (o.can('return')) {
      buttons.add(FilledButton(
        onPressed: _busy ? null : () => _openHandover(false),
        child: const Text('Xác nhận đã trả đồ'),
      ));
    }
    if (o.can('deposit')) {
      buttons.add(FilledButton(
        onPressed: _busy ? null : _openDeposit,
        child: const Text('Ghi kết quả tiền cọc'),
      ));
    }
    if (o.can('cancel')) {
      buttons.add(OutlinedButton(
        onPressed: _busy
            ? null
            : () async {
                final r = await _askReason(
                    'Hủy đơn thuê', 'Ví dụ: Thay đổi lịch học');
                if (r != null) {
                  await _runOrderAction(() => ref
                      .read(apiClientProvider)
                      .cancelOrder(o.id, reason: r));
                }
              },
        child: const Text('Hủy đơn'),
      ));
    }
    if (o.can('report') && o.status == 'approved' && o.pickup.length == 1) {
      buttons.add(OutlinedButton.icon(
        onPressed: () => context.push(
          '/cases/new?targetType=order&targetId=${o.id}&category=handover',
        ),
        icon: const Icon(Icons.report_problem_outlined),
        label: const Text('Báo chưa nhận / sự cố giao'),
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}

class _ReceiptsCard extends StatelessWidget {
  const _ReceiptsCard({
    required this.title,
    required this.receipts,
    required this.ownerId,
  });

  final String title;
  final List<Receipt> receipts;
  final String ownerId;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: tt.titleMedium),
            const SizedBox(height: 8),
            if (receipts.isEmpty)
              const Text('Chưa có bên nào xác nhận.')
            else
              for (final r in receipts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.actorId == ownerId ? 'Chủ đồ' : 'Người thuê'} · ${formatTimestampVi(r.confirmedAt)}',
                        style: tt.labelLarge,
                      ),
                      Text('Tình trạng: ${r.condition}'),
                      if (r.cashReceived != null)
                        Text('Tiền thực trao: ${formatVnd(r.cashReceived!)}'),
                      if (r.photoIds.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final pid in r.photoIds)
                              SizedBox(
                                width: 88,
                                child: AuthImage(photoId: pid, borderRadius: 8),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
