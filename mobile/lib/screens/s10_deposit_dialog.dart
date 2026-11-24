import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../models/order.dart';
import '../state/app_providers.dart';
import '../widgets/common_ui.dart';

class DepositDialog extends ConsumerStatefulWidget {
  const DepositDialog({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<DepositDialog> createState() => _DepositDialogState();
}

class _DepositDialogState extends ConsumerState<DepositDialog> {
  late final TextEditingController _refundCtrl;
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _idempKey;

  @override
  void initState() {
    super.initState();
    _refundCtrl = TextEditingController(
      text: '${widget.order.quote.deposit}',
    );
  }

  @override
  void dispose() {
    _refundCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final refunded = int.tryParse(_refundCtrl.text.trim());
    if (refunded == null ||
        refunded < 0 ||
        refunded > widget.order.quote.deposit) {
      setState(() => _error =
          'Số tiền hoàn phải từ 0đ đến ${formatVnd(widget.order.quote.deposit)}.');
      return;
    }
    if (refunded < widget.order.quote.deposit &&
        _reasonCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Bắt buộc nêu lý do khi hoàn thiếu tiền cọc.');
      return;
    }
    _idempKey ??= newUuidV4();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await ref.read(apiClientProvider).confirmDeposit(
            widget.order.id,
            refunded: refunded,
            reason: _reasonCtrl.text.trim(),
            idempotencyKey: _idempKey,
          );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageFrom(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kết quả tiền cọc (S10)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mức cọc đã giữ: ${formatVnd(widget.order.quote.deposit)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Nếu hai bên nhập cùng số tiền, đơn hoàn tất. Nếu khác nhau, hệ thống tự mở vụ việc để quản trị viên xử lý.',
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              InlineAlertBanner(message: _error!, tone: StatusTone.error),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _refundCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số tiền cọc đã hoàn (VND)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Lý do khấu trừ (bắt buộc nếu hoàn thiếu)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Đang gửi...' : 'Xác nhận hoàn cọc'),
        ),
      ],
    );
  }
}
