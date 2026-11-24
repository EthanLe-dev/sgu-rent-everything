import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_providers.dart';

/// Hiển thị ảnh tỷ lệ 4:3 theo `api-contract.md`:
/// - Ảnh thật (`photo-*`) tải qua `GET /photos/{id}` có `Authorization: Bearer`.
/// - Ảnh mẫu (`mock-*`) hiển thị thẻ minh họa sạch sẽ, không phụ thuộc mạng ngoài.
class AuthImage extends ConsumerStatefulWidget {
  const AuthImage({
    super.key,
    required this.photoId,
    this.borderRadius = 12,
    this.aspectRatio = 4 / 3,
  });

  final String? photoId;
  final double borderRadius;
  final double aspectRatio;

  @override
  ConsumerState<AuthImage> createState() => _AuthImageState();
}

class _AuthImageState extends ConsumerState<AuthImage> {
  Future<Uint8List>? _future;
  String? _loadedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant AuthImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId) {
      _maybeLoad();
    }
  }

  void _maybeLoad() {
    final id = widget.photoId;
    if (id == null || id.isEmpty || id.startsWith('mock-')) {
      _future = null;
      _loadedId = id;
      return;
    }
    if (_loadedId == id && _future != null) return;
    _loadedId = id;
    _future = ref.read(apiClientProvider).getPhotoBytes(id);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.photoId;
    final cs = Theme.of(context).colorScheme;

    Widget child;
    if (id == null || id.isEmpty) {
      child = _MockVisual(icon: Icons.inventory_2_outlined, label: 'Chưa có ảnh');
    } else if (id.startsWith('mock-')) {
      final (icon, label) = switch (id) {
        'mock-camera' => (Icons.photo_camera_outlined, 'Sony ZV-E10'),
        'mock-calc' => (Icons.calculate_outlined, 'Casio fx-580VN X'),
        'mock-aodai' => (Icons.checkroom_outlined, 'Áo dài trắng'),
        'mock-mic' => (Icons.mic_none_outlined, 'DJI Mic'),
        _ => (Icons.image_outlined, 'Ảnh món đồ'),
      };
      child = _MockVisual(icon: icon, label: label);
    } else {
      child = FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Container(
              color: cs.surfaceContainer,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (snap.hasError || !snap.hasData) {
            return const _MockVisual(
              icon: Icons.broken_image_outlined,
              label: 'Không tải được ảnh',
            );
          }
          return Image.memory(snap.data!, fit: BoxFit.cover);
        },
      );
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: child,
      ),
    );
  }
}

class _MockVisual extends StatelessWidget {
  const _MockVisual({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerLow,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: cs.primary),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
