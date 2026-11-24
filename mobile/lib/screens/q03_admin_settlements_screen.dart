import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../models/api_error.dart';
import '../models/case_fee.dart';
import '../state/app_providers.dart';
import '../widgets/common_ui.dart';

class AdminSettlementsScreen extends ConsumerStatefulWidget {
  const AdminSettlementsScreen({super.key});

  @override
  ConsumerState<AdminSettlementsScreen> createState() =>
      _AdminSettlementsScreenState();
}

class _AdminSettlementsScreenState
    extends ConsumerState<AdminSettlementsScreen> {
  List<OwnerFees> _owners = const [];
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
      final page = await ref.read(apiClientProvider).getAdminFeeOwners();
      if (!mounted) return;
      setState(() {
        _owners = page.items;
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

  Future<void> _openSettleSheet(OwnerFees ownerFees) async {
    final settled = await showModalBottomSheet<Settlement>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OwnerSettleSheet(ownerFees: ownerFees),
    );
    if (settled != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã xác nhận nhận ${formatVnd(settled.receivedAmount)} (${settled.orderIds.length} đơn).',
          ),
        ),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).value;
    if (me == null || !me.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đối soát phí (Q03)')),
        body: const EmptyStateView(
          icon: Icons.lock_outline,
          title: 'Không có quyền truy cập',
          message: 'Chỉ quản trị viên mới được xác nhận đối soát.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Đối soát phí (Q03)')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorStateView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_owners.isEmpty)
                        const EmptyStateView(
                          icon: Icons.account_balance_outlined,
                          title: 'Chưa có chủ đồ phát sinh phí',
                          message: 'Khi có đơn giao thành công, phí sẽ hiện tại đây.',
                        )
                      else
                        for (final o in _owners)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(o.owner.displayName),
                              subtitle: Text(
                                'Tổng phát sinh: ${formatVnd(o.summary.accrued)} · Đã đối soát: ${formatVnd(o.summary.settled)}',
                              ),
                              trailing: FilledButton.tonal(
                                onPressed: () => _openSettleSheet(o),
                                child: Text(
                                  o.summary.outstanding > 0
                                      ? 'Thu ${formatVnd(o.summary.outstanding)}'
                                      : 'Xem chi tiết',
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}

class _OwnerSettleSheet extends ConsumerStatefulWidget {
  const _OwnerSettleSheet({required this.ownerFees});

  final OwnerFees ownerFees;

  @override
  ConsumerState<_OwnerSettleSheet> createState() => _OwnerSettleSheetState();
}

class _OwnerSettleSheetState extends ConsumerState<_OwnerSettleSheet> {
  List<FeeEntry> _entries = const [];
  final Set<String> _selected = {};
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _idempKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(apiClientProvider)
          .getAdminOwnerFeeEntries(widget.ownerFees.owner.id, state: 'outstanding');
      if (!mounted) return;
      setState(() {
        _entries = page.items;
        _selected
          ..clear()
          ..addAll(page.items.map((e) => e.orderId));
        _syncExpectedAmount();
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

  void _syncExpectedAmount() {
    final sum = _entries
        .where((e) => _selected.contains(e.orderId))
        .fold<int>(0, (acc, e) => acc + e.total);
    _amountCtrl.text = '$sum';
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      setState(() => _error = 'Chọn ít nhất một đơn để đối soát.');
      return;
    }
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? -1;
    if (_refCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nhập mã tham chiếu giao dịch chuyển khoản.');
      return;
    }
    _idempKey ??= newUuidV4();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final stl = await ref.read(apiClientProvider).createSettlement(
            ownerId: widget.ownerFees.owner.id,
            orderIds: _selected.toList(),
            receivedAmount: amount,
            reference: _refCtrl.text.trim(),
            idempotencyKey: _idempKey,
          );
      if (!mounted) return;
      Navigator.pop(context, stl);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.code == 'already_settled') {
        _idempKey = null;
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageFrom(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expected = _entries
        .where((e) => _selected.contains(e.orderId))
        .fold<int>(0, (acc, e) => acc + e.total);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Đối soát: ${widget.ownerFees.owner.displayName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_error != null) ...[
              InlineAlertBanner(message: _error!, tone: StatusTone.error),
              const SizedBox(height: 12),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Chủ đồ này không còn đơn nào chờ đối soát.'),
              )
            else ...[
              for (final e in _entries)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(e.orderId),
                  title: Text('Đơn ${e.orderId}'),
                  subtitle: Text(
                    'Chủ ${formatVnd(e.ownerFee)} + Thu hộ ${formatVnd(e.renterFee)}',
                  ),
                  secondary: Text(formatVnd(e.total)),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(e.orderId);
                      } else {
                        _selected.remove(e.orderId);
                      }
                      _syncExpectedAmount();
                    });
                  },
                ),
              const Divider(),
              const SizedBox(height: 8),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Số tiền thực nhận (VND)',
                  helperText: 'Tổng các đơn đã chọn: ${formatVnd(expected)}',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã tham chiếu chuyển khoản',
                  hintText: 'Ví dụ: VCB-20261124-01',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(
                  _submitting
                      ? 'Đang xác nhận...'
                      : 'Ghi nhận đã nhận ${formatVnd(expected)}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
