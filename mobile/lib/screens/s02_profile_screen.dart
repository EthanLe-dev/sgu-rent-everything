import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../services/mock_api_client.dart';
import '../state/app_providers.dart';
import '../widgets/common_ui.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _studentCodeCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _facultyCtrl = TextEditingController();

  String? _seededUserId;
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _displayCtrl.dispose();
    _fullNameCtrl.dispose();
    _studentCodeCtrl.dispose();
    _classCtrl.dispose();
    _facultyCtrl.dispose();
    super.dispose();
  }

  void _syncFromMe(Me me) {
    if (_seededUserId == me.id) return;
    _seededUserId = me.id;
    _displayCtrl.text = me.displayName;
    _fullNameCtrl.text = me.fullName ?? '';
    _studentCodeCtrl.text = me.studentCode ?? '';
    _classCtrl.text = me.className ?? '';
    _facultyCtrl.text = me.faculty ?? '';
  }

  Future<void> _submitVerification() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      await ref.read(authProvider.notifier).submitVerification(
            displayName: _displayCtrl.text.trim(),
            fullName: _fullNameCtrl.text.trim(),
            studentCode: _studentCodeCtrl.text.trim(),
            className: _classCtrl.text.trim(),
            faculty: _facultyCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _success =
            'Đã gửi hồ sơ xác minh. Mang thẻ sinh viên hoặc mở cổng sinh viên để đối chiếu trực tiếp.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageFrom(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editBaseUrlDialog() async {
    final cfg = ref.read(configProvider);
    final ctrl = TextEditingController(text: cfg.apiBaseUrl);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Địa chỉ Backend (/v1)'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Base URL',
            hintText: 'http://10.0.2.2:8080/v1',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Lưu địa chỉ'),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty) {
      await ref.read(configProvider.notifier).updateConfig(apiBaseUrl: res);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final cfg = ref.watch(configProvider);
    final api = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân & Xác minh'),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: authAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(
          error: e,
          onRetry: () => ref.read(authProvider.notifier).refreshMe(),
        ),
        data: (me) {
          if (me == null) {
            return EmptyStateView(
              icon: Icons.person_outline,
              title: 'Bạn chưa đăng nhập',
              message:
                  'Đăng nhập bằng email sinh viên ĐH Sài Gòn để xác minh, đăng đồ và quản lý giao dịch.',
              actionLabel: 'Đăng nhập ngay',
              onAction: () => context.go('/login?redirect=/profile'),
            );
          }
          _syncFromMe(me);
          final canEditVerification =
              me.verification == VerificationStatus.unsubmitted ||
                  me.verification == VerificationStatus.rejected;

          final (badgeIcon, badgeTone) = switch (me.verification) {
            VerificationStatus.approved => (
                Icons.verified,
                StatusTone.success,
              ),
            VerificationStatus.pending => (
                Icons.hourglass_top,
                StatusTone.warning,
              ),
            VerificationStatus.rejected => (
                Icons.cancel_outlined,
                StatusTone.error,
              ),
            VerificationStatus.unsubmitted => (
                Icons.info_outline,
                StatusTone.neutral,
              ),
          };

          return ListView(
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
                          CircleAvatar(
                            radius: 24,
                            child: Text(me.displayName.characters.first),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  me.displayName,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  me.email,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            label: me.verificationLabel,
                            icon: badgeIcon,
                            tone: badgeTone,
                          ),
                        ],
                      ),
                      if (me.verification == VerificationStatus.rejected &&
                          me.reviewNote != null) ...[
                        const SizedBox(height: 12),
                        InlineAlertBanner(
                          message: 'Lý do từ chối: ${me.reviewNote}',
                          tone: StatusTone.error,
                        ),
                      ],
                      if (me.verification == VerificationStatus.pending) ...[
                        const SizedBox(height: 12),
                        const InlineAlertBanner(
                          message:
                              'Hồ sơ đang chờ duyệt. Mang thẻ sinh viên hoặc mở cổng sinh viên để đối chiếu trực tiếp với quản trị viên.',
                          tone: StatusTone.warning,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (me.isAdmin) ...[
                Text(
                  'Công cụ quản trị viên',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.how_to_reg_outlined),
                        title: const Text('Duyệt sinh viên (Q01)'),
                        subtitle: const Text('Hàng đợi đối chiếu trực tiếp'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/admin/verifications'),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.gavel_outlined),
                        title: const Text('Xử lý vụ việc (Q02)'),
                        subtitle:
                            const Text('Tranh chấp giao nhận, cọc và báo cáo'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/admin/cases'),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.account_balance_outlined),
                        title: const Text('Đối soát phí (Q03)'),
                        subtitle:
                            const Text('Xác nhận khoản chuyển gộp từ chủ đồ'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/admin/settlements'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Tiện ích tài khoản',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: const Text('Tin của tôi & Lịch bận'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/my-listings'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: const Text('Phí và đối soát của chủ đồ'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/fees'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.report_problem_outlined),
                      title: const Text('Vụ việc của tôi'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/cases'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hồ sơ xác minh sinh viên',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          InlineAlertBanner(
                            message: _error!,
                            tone: StatusTone.error,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_success != null) ...[
                          InlineAlertBanner(
                            message: _success!,
                            tone: StatusTone.success,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _displayCtrl,
                          enabled: canEditVerification,
                          decoration: const InputDecoration(
                            labelText: 'Tên hiển thị công khai',
                            helperText:
                                'Chỉ tên hiển thị và dấu đã xác minh xuất hiện trên tin.',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _fullNameCtrl,
                          enabled: canEditVerification,
                          decoration: const InputDecoration(labelText: 'Họ và tên'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _studentCodeCtrl,
                          enabled: canEditVerification,
                          decoration:
                              const InputDecoration(labelText: 'Mã sinh viên'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _classCtrl,
                                enabled: canEditVerification,
                                decoration:
                                    const InputDecoration(labelText: 'Lớp'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Bắt buộc'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _facultyCtrl,
                                enabled: canEditVerification,
                                decoration:
                                    const InputDecoration(labelText: 'Khoa'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Bắt buộc'
                                        : null,
                              ),
                            ),
                          ],
                        ),
                        if (canEditVerification) ...[
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _saving ? null : _submitVerification,
                            child: Text(
                              _saving
                                  ? 'Đang gửi hồ sơ...'
                                  : me.verification ==
                                          VerificationStatus.rejected
                                      ? 'Gửi lại hồ sơ xác minh'
                                      : 'Nộp hồ sơ xác minh',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cấu hình kết nối & kiểm thử',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Dùng dữ liệu mẫu (Mock)'),
                      subtitle: Text(
                        cfg.useMock
                            ? 'Đang chạy độc lập bằng Mock engine'
                            : 'Đang gọi API thật: ${cfg.apiBaseUrl}',
                      ),
                      value: cfg.useMock,
                      onChanged: (v) async {
                        await ref
                            .read(configProvider.notifier)
                            .updateConfig(useMock: v);
                        await ref.read(authProvider.notifier).logout();
                      },
                    ),
                    if (!cfg.useMock && !kIsWeb)
                      ListTile(
                        leading: const Icon(Icons.link),
                        title: const Text('Đổi Base URL Android'),
                        subtitle: Text(cfg.apiBaseUrl),
                        onTap: _editBaseUrlDialog,
                      ),
                    if (api is MockRentApiClient)
                      SwitchListTile(
                        title: const Text('Giả lập mất mạng ở lệnh kế tiếp'),
                        subtitle: const Text(
                          'Dùng để kiểm tra giữ dữ liệu và thử lại an toàn',
                        ),
                        value: api.simulateNextNetworkError,
                        onChanged: (v) {
                          setState(() => api.simulateNextNetworkError = v);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
