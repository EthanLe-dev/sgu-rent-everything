import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/formatters.dart';
import '../models/order.dart';
import '../state/app_providers.dart';
import '../widgets/auth_image.dart';
import '../widgets/common_ui.dart';

class HandoverSheet extends ConsumerStatefulWidget {
  const HandoverSheet({
    super.key,
    required this.order,
    required this.isPickup,
  });

  final Order order;
  final bool isPickup;

  @override
  ConsumerState<HandoverSheet> createState() => _HandoverSheetState();
}

class _HandoverSheetState extends ConsumerState<HandoverSheet> {
  final _condCtrl = TextEditingController(text: 'Đầy đủ, hoạt động bình thường');
  late final TextEditingController _cashCtrl;
  late Set<String> _selectedAccessories;
  List<String> _photoIds = [];
  bool _uploading = false;
  bool _submitting = false;
  String? _error;
  String? _idempKey;

  @override
  void initState() {
    super.initState();
    _cashCtrl = TextEditingController(
      text: '${widget.order.quote.pickupTotal}',
    );
    _selectedAccessories = widget.order.accessories.toSet();
  }

  @override
  void dispose() {
    _condCtrl.dispose();
    _cashCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final mime =
        xfile.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    if (bytes.length > 8 * 1024 * 1024) {
      setState(() => _error = 'Ảnh vượt quá 8 MiB.');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final pid = await ref.read(apiClientProvider).uploadPhoto(
            bytes: bytes,
            filename: xfile.name,
            mimeType: mime,
            purpose: 'handover',
            orderId: widget.order.id,
          );
      if (!mounted) return;
      setState(() => _photoIds = [..._photoIds, pid]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageFrom(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_condCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng ghi tình trạng món đồ.');
      return;
    }
    _idempKey ??= newUuidV4();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final Order updated;
      if (widget.isPickup) {
        final cash = int.tryParse(_cashCtrl.text.trim()) ?? -1;
        updated = await api.confirmPickup(
          widget.order.id,
          condition: _condCtrl.text.trim(),
          accessories: _selectedAccessories.toList(),
          photoIds: _photoIds,
          cashReceived: cash,
          idempotencyKey: _idempKey,
        );
      } else {
        updated = await api.confirmReturn(
          widget.order.id,
          condition: _condCtrl.text.trim(),
          accessories: _selectedAccessories.toList(),
          photoIds: _photoIds,
          idempotencyKey: _idempKey,
        );
      }
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
    final tt = Theme.of(context).textTheme;
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
              widget.isPickup
                  ? 'Biên nhận giao đồ (S09)'
                  : 'Biên nhận trả đồ (S09)',
              style: tt.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              widget.isPickup
                  ? 'Đủ hai xác nhận giao mới chuyển sang Đang thuê và ghi phí 1.000đ mỗi bên.'
                  : 'Xác nhận trả đồ tách biệt với bước hoàn tiền cọc.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              InlineAlertBanner(message: _error!, tone: StatusTone.error),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _condCtrl,
              decoration: const InputDecoration(labelText: 'Tình trạng thực tế'),
            ),
            if (widget.order.accessories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Phụ kiện kiểm tra', style: tt.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final acc in widget.order.accessories)
                    FilterChip(
                      label: Text(acc),
                      selected: _selectedAccessories.contains(acc),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _selectedAccessories.add(acc);
                        } else {
                          _selectedAccessories.remove(acc);
                        }
                      }),
                    ),
                ],
              ),
            ],
            if (widget.isPickup) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _cashCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Số tiền thực trao (VND)',
                  helperText:
                      'Đúng bằng tổng đã chốt: ${formatVnd(widget.order.quote.pickupTotal)}',
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pid in _photoIds)
                  SizedBox(
                    width: 84,
                    child: AuthImage(photoId: pid, borderRadius: 8),
                  ),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_uploading ? 'Đang tải...' : 'Ảnh bàn giao (tùy chọn)'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(
                _submitting
                    ? 'Đang xác nhận...'
                    : widget.isPickup
                        ? 'Xác nhận đã giao/nhận máy'
                        : 'Xác nhận đã trả máy',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
