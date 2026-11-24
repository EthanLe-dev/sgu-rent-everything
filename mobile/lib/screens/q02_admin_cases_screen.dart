import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/case_fee.dart';
import '../state/app_providers.dart';
import '../widgets/common_ui.dart';

class AdminCasesScreen extends ConsumerStatefulWidget {
  const AdminCasesScreen({super.key});

  @override
  ConsumerState<AdminCasesScreen> createState() => _AdminCasesScreenState();
}

class _AdminCasesScreenState extends ConsumerState<AdminCasesScreen> {
  List<CaseItem> _items = const [];
  String? _statusFilter = 'open';
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
      final page = await ref
          .read(apiClientProvider)
          .getAdminCases(status: _statusFilter);
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

  Future<void> _resolveDialog(CaseItem c) async {
    final resCtrl = TextEditingController();
    final refundCtrl = TextEditingController(text: '0');
    String outcome = 'resume';
    String? dialogErr;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Xử lý vụ việc (${c.categoryLabelVi})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(c.detail),
                const SizedBox(height: 12),
                if (dialogErr != null) ...[
                  InlineAlertBanner(
                    message: dialogErr!,
                    tone: StatusTone.error,
                  ),
                  const SizedBox(height: 8),
                ],
                if (c.category == 'handover')
                  DropdownButtonFormField<String>(
                    initialValue: outcome,
                    decoration:
                        const InputDecoration(labelText: 'Quyết định bàn giao'),
                    items: const [
                      DropdownMenuItem(
                        value: 'resume',
                        child: Text('Cho tiếp tục xác nhận giao'),
                      ),
                      DropdownMenuItem(
                        value: 'cancel_unhanded',
                        child: Text('Đóng đơn chưa giao (phí 0đ)'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => outcome = v);
                    },
                  ),
                if (c.category == 'deposit')
                  TextField(
                    controller: refundCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số tiền hoàn cọc cuối cùng (VND)',
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: resCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú kết luận',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                if (resCtrl.text.trim().isEmpty) {
                  setDlgState(() => dialogErr = 'Vui lòng nhập kết luận.');
                  return;
                }
                try {
                  await ref.read(apiClientProvider).resolveCase(
                        c.id,
                        resolution: resCtrl.text.trim(),
                        refunded: c.category == 'deposit'
                            ? int.tryParse(refundCtrl.text.trim())
                            : null,
                        handoverOutcome:
                            c.category == 'handover' ? outcome : null,
                      );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  setDlgState(() => dialogErr = errorMessageFrom(e));
                }
              },
              child: const Text('Gửi kết quả'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).value;
    if (me == null || !me.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Xử lý vụ việc (Q02)')),
        body: const EmptyStateView(
          icon: Icons.lock_outline,
          title: 'Không có quyền truy cập',
          message: 'Chỉ quản trị viên mới được xử lý vụ việc.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Xử lý vụ việc (Q02)')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorStateView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          for (final (code, label) in const [
                            ('open', 'Đang mở'),
                            ('resolved', 'Đã xử lý'),
                            (null, 'Tất cả'),
                          ]) ...[
                            FilterChip(
                              label: Text(label),
                              selected: _statusFilter == code,
                              onSelected: (_) {
                                _statusFilter = code;
                                _load();
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_items.isEmpty)
                        const EmptyStateView(
                          icon: Icons.gavel_outlined,
                          title: 'Không có vụ việc nào',
                          message: 'Danh sách vụ việc theo bộ lọc đang trống.',
                        )
                      else
                        for (final c in _items)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${c.categoryLabelVi} · ${c.targetType == 'order' ? 'Đơn' : 'Tin'} ${c.targetId}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                      ),
                                      StatusBadge(
                                        label: c.isOpen ? 'Đang mở' : 'Đã xử lý',
                                        icon: c.isOpen
                                            ? Icons.pending_outlined
                                            : Icons.check_circle_outline,
                                        tone: c.isOpen
                                            ? StatusTone.warning
                                            : StatusTone.success,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(c.detail),
                                  if (c.resolution != null) ...[
                                    const SizedBox(height: 8),
                                    InlineAlertBanner(
                                      message: 'Kết luận: ${c.resolution}',
                                      tone: StatusTone.success,
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      if (c.targetType == 'order')
                                        OutlinedButton(
                                          onPressed: () => context
                                              .push('/orders/${c.targetId}'),
                                          child: const Text('Xem đơn & bằng chứng'),
                                        ),
                                      if (c.targetType == 'order')
                                        const SizedBox(width: 8),
                                      if (c.isOpen)
                                        FilledButton(
                                          onPressed: () => _resolveDialog(c),
                                          child: const Text('Ghi quyết định'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}
