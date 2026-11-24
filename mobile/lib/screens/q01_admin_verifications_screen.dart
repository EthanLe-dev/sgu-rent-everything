import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../state/app_providers.dart';
import '../widgets/common_ui.dart';

class AdminVerificationsScreen extends ConsumerStatefulWidget {
  const AdminVerificationsScreen({super.key});

  @override
  ConsumerState<AdminVerificationsScreen> createState() =>
      _AdminVerificationsScreenState();
}

class _AdminVerificationsScreenState
    extends ConsumerState<AdminVerificationsScreen> {
  List<Me> _items = const [];
  bool _loading = true;
  Object? _error;
  String? _actionError;

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
          await ref.read(apiClientProvider).getAdminVerifications();
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

  Future<void> _review(Me user, String decision) async {
    String? note;
    if (decision == 'reject') {
      final ctrl = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Từ chối hồ sơ ${user.displayName}'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Ghi chú lý do',
              hintText: 'Ví dụ: Mã sinh viên chưa khớp thẻ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Từ chối'),
            ),
          ],
        ),
      );
      if (note == null) return;
    }

    setState(() => _actionError = null);
    try {
      await ref.read(apiClientProvider).reviewVerification(
            user.id,
            decision: decision,
            note: note,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = errorMessageFrom(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).value;
    if (me == null || !me.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Duyệt sinh viên (Q01)')),
        body: const EmptyStateView(
          icon: Icons.lock_outline,
          title: 'Không có quyền truy cập',
          message: 'Chỉ quản trị viên mới được phép duyệt hồ sơ sinh viên.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Duyệt sinh viên (Q01)')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorStateView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_actionError != null) ...[
                        InlineAlertBanner(
                          message: _actionError!,
                          tone: StatusTone.error,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_items.isEmpty)
                        const EmptyStateView(
                          icon: Icons.how_to_reg_outlined,
                          title: 'Không còn hồ sơ chờ duyệt',
                          message: 'Hàng đợi đối chiếu sinh viên hiện đang trống.',
                        )
                      else
                        for (final u in _items)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${u.fullName ?? u.displayName} (${u.displayName})',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Email: ${u.email}'),
                                  Text(
                                    'MSSV: ${u.studentCode ?? '-'} · Lớp: ${u.className ?? '-'} · Khoa: ${u.faculty ?? '-'}',
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _review(u, 'reject'),
                                          child: const Text('Từ chối'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () => _review(u, 'approve'),
                                          child: const Text('Duyệt sinh viên'),
                                        ),
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
