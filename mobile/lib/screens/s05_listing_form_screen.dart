import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/formatters.dart';
import '../models/listing.dart';
import '../state/app_providers.dart';
import '../state/explore_provider.dart';
import '../widgets/auth_image.dart';
import '../widgets/common_ui.dart';

class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({super.key, this.listingId});

  final String? listingId;

  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  static const _draftKey = 'sgu_rent_listing_draft_v1';

  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _condCtrl = TextEditingController();
  final _accCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _depositCtrl = TextEditingController(text: '0');

  String _category = 'Máy ảnh & Quay phim';
  String _area = 'Cơ sở 1';
  List<String> _photoIds = [];
  Uint8List? _lastFailedPhotoBytes;
  String? _lastFailedPhotoName;
  String? _lastFailedPhotoMime;

  bool get isEditing => widget.listingId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _condCtrl.dispose();
    _accCtrl.dispose();
    _rateCtrl.dispose();
    _depositCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (isEditing) {
      try {
        final l =
            await ref.read(apiClientProvider).getListing(widget.listingId!);
        if (!mounted) return;
        _titleCtrl.text = l.title;
        _descCtrl.text = l.description;
        _condCtrl.text = l.condition;
        _accCtrl.text = l.accessories.join(', ');
        _rateCtrl.text = '${l.dailyRate}';
        _depositCtrl.text = '${l.deposit}';
        _category = l.category;
        _area = l.area;
        _photoIds = List.of(l.photoIds);
      } catch (e) {
        _error = errorMessageFrom(e);
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw != null) {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          _titleCtrl.text = m['title'] as String? ?? '';
          _descCtrl.text = m['description'] as String? ?? '';
          _condCtrl.text = m['condition'] as String? ?? '';
          _accCtrl.text = m['accessories'] as String? ?? '';
          _rateCtrl.text = m['daily_rate'] as String? ?? '';
          _depositCtrl.text = m['deposit'] as String? ?? '0';
          _category = m['category'] as String? ?? _category;
          _area = m['area'] as String? ?? _area;
          _photoIds = List<String>.from(m['photo_ids'] as List? ?? const []);
        } catch (_) {}
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveDraft() async {
    if (isEditing) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _draftKey,
      jsonEncode({
        'title': _titleCtrl.text,
        'description': _descCtrl.text,
        'condition': _condCtrl.text,
        'accessories': _accCtrl.text,
        'daily_rate': _rateCtrl.text,
        'deposit': _depositCtrl.text,
        'category': _category,
        'area': _area,
        'photo_ids': _photoIds,
      }),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu nháp trên thiết bị')),
    );
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final name = xfile.name.toLowerCase();
    final mime = name.endsWith('.png') ? 'image/png' : 'image/jpeg';

    if (bytes.length > 8 * 1024 * 1024) {
      setState(() => _error = 'Ảnh vượt quá giới hạn 8 MiB. Vui lòng chọn ảnh nhỏ hơn.');
      return;
    }
    await _uploadBytes(bytes, xfile.name, mime);
  }

  Future<void> _uploadBytes(
    Uint8List bytes,
    String filename,
    String mime,
  ) async {
    setState(() {
      _uploadingPhoto = true;
      _error = null;
    });
    try {
      final id = await ref.read(apiClientProvider).uploadPhoto(
            bytes: bytes,
            filename: filename,
            mimeType: mime,
            purpose: 'listing',
          );
      if (!mounted) return;
      setState(() {
        _photoIds = [..._photoIds, id];
        _lastFailedPhotoBytes = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessageFrom(e);
        _lastFailedPhotoBytes = bytes;
        _lastFailedPhotoName = filename;
        _lastFailedPhotoMime = mime;
      });
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    final rate = int.tryParse(_rateCtrl.text.trim());
    final deposit = int.tryParse(_depositCtrl.text.trim()) ?? 0;
    if (_titleCtrl.text.trim().isEmpty ||
        _condCtrl.text.trim().isEmpty ||
        rate == null ||
        rate <= 0 ||
        deposit < 0) {
      setState(() => _error = 'Vui lòng nhập đầy đủ tên món, tình trạng và giá hợp lệ.');
      return;
    }
    final accessories = _accCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final input = ListingInput(
      title: _titleCtrl.text.trim(),
      category: _category,
      description: _descCtrl.text.trim(),
      condition: _condCtrl.text.trim(),
      accessories: accessories,
      photoIds: _photoIds.isEmpty ? ['mock-camera'] : _photoIds,
      dailyRate: rate,
      deposit: deposit,
      area: _area,
      pickupPoint: _area,
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final saved = isEditing
          ? await api.updateListing(widget.listingId!, input.toJson())
          : await api.createListing(input);
      if (!isEditing) await _clearDraft();
      ref.invalidate(exploreProvider);
      if (!mounted) return;
      context.go('/listings/${saved.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageFrom(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).value;
    final catalogAsync = ref.watch(catalogOptionsProvider);

    if (me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đăng đồ cho thuê')),
        body: EmptyStateView(
          icon: Icons.lock_outline,
          title: 'Cần đăng nhập để đăng đồ',
          message: 'Đăng nhập bằng email sinh viên ĐH Sài Gòn để tiếp tục.',
          actionLabel: 'Đăng nhập',
          onAction: () => context.go('/login?redirect=/post'),
        ),
      );
    }
    if (!me.isApproved) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đăng đồ cho thuê')),
        body: EmptyStateView(
          icon: Icons.verified_user_outlined,
          title: 'Tài khoản chưa được duyệt',
          message:
              'Sinh viên chờ duyệt chưa thể đăng đồ. Hoàn tất xác minh trực tiếp để mở khóa.',
          actionLabel: 'Đi tới xác minh',
          onAction: () => context.go('/profile'),
        ),
      );
    }

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Sửa tin đăng' : 'Đăng đồ cho thuê'),
        ),
        body: const LoadingView(),
      );
    }

    final categories = catalogAsync.value?.categories ??
        const [
          'Máy ảnh & Quay phim',
          'Học tập & Thi cử',
          'Trang phục & Sự kiện',
          'Thiết bị điện tử',
        ];
    final areas = catalogAsync.value?.areas ??
        const ['Cơ sở 1', 'Cơ sở 2', 'Cơ sở Chính'];

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa tin đăng' : 'Đăng đồ cho thuê'),
        actions: [
          if (!isEditing)
            TextButton.icon(
              onPressed: _saveDraft,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Lưu nháp'),
            ),
        ],
      ),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () {
          if (_step < 2) {
            setState(() => _step++);
          } else {
            _submit();
          }
        },
        onStepCancel: () {
          if (_step > 0) setState(() => _step--);
        },
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : details.onStepContinue,
                  child: Text(
                    _step < 2
                        ? 'Tiếp tục'
                        : (_saving
                            ? 'Đang lưu...'
                            : isEditing
                                ? 'Lưu thay đổi'
                                : 'Đăng tin ngay'),
                  ),
                ),
              ),
              if (_step > 0) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _saving ? null : details.onStepCancel,
                  child: const Text('Quay lại'),
                ),
              ],
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text('1. Ảnh & Thông tin món'),
            isActive: _step >= 0,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  InlineAlertBanner(
                    message: _error!,
                    tone: StatusTone.error,
                    actionLabel: _lastFailedPhotoBytes != null ? 'Thử lại' : null,
                    onAction: _lastFailedPhotoBytes != null
                        ? () => _uploadBytes(
                              _lastFailedPhotoBytes!,
                              _lastFailedPhotoName ?? 'photo.jpg',
                              _lastFailedPhotoMime ?? 'image/jpeg',
                            )
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final pid in _photoIds)
                      Stack(
                        children: [
                          SizedBox(
                            width: 112,
                            child: AuthImage(photoId: pid, borderRadius: 10),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close,
                                    size: 16, color: Colors.white),
                                onPressed: () => setState(() =>
                                    _photoIds = _photoIds
                                        .where((e) => e != pid)
                                        .toList()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    OutlinedButton.icon(
                      onPressed: _uploadingPhoto ? null : _pickAndUploadPhoto,
                      icon: _uploadingPhoto
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_a_photo_outlined),
                      label: Text(_uploadingPhoto
                          ? 'Đang tải ảnh...'
                          : 'Thêm ảnh (JPEG/PNG ≤ 8 MiB)'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên món đồ',
                    hintText: 'Ví dụ: Máy ảnh Sony ZV-E10',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categories.contains(_category)
                      ? _category
                      : categories.first,
                  decoration: const InputDecoration(labelText: 'Loại đồ'),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả chi tiết',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _condCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tình trạng hiện tại',
                    hintText: 'Ví dụ: Mới 98%, hoạt động ổn định',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phụ kiện đi kèm (cách nhau bởi dấu phẩy)',
                    hintText: '1 pin zin, Sạc USB-C, Túi đựng',
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('2. Giá thuê & Tiền cọc'),
            isActive: _step >= 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _rateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giá thuê mỗi ngày (VND)',
                    hintText: '50000',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _depositCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tiền cọc (VND, nhập 0 nếu không cần cọc)',
                    hintText: '300000',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lưu ý: Phí duy trì 1.000đ mỗi bên chỉ phát sinh sau khi đủ hai xác nhận giao.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('3. Điểm hẹn & Xem trước'),
            isActive: _step >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: areas.contains(_area) ? _area : areas.first,
                  decoration: const InputDecoration(
                    labelText: 'Cơ sở giao nhận (ĐH Sài Gòn)',
                  ),
                  items: [
                    for (final a in areas)
                      DropdownMenuItem(value: a, child: Text(a)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _area = v);
                  },
                ),
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Xem trước tin',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 6),
                        Text(
                          _titleCtrl.text.trim().isEmpty
                              ? '(Chưa nhập tên món)'
                              : _titleCtrl.text.trim(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatVnd(int.tryParse(_rateCtrl.text) ?? 0)}/ngày · Cọc ${formatVnd(int.tryParse(_depositCtrl.text) ?? 0)} · $_area',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
