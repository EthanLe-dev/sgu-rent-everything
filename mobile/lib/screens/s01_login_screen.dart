import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/api_error.dart';
import '../models/user.dart';
import '../state/app_providers.dart';
import '../widgets/common_ui.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController(text: 'minh@sgu.edu.vn');
  final _otpCtrl = TextEditingController();

  OtpChallenge? _challenge;
  bool _loading = false;
  String? _error;
  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _resendSeconds = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ch = await ref
          .read(authProvider.notifier)
          .requestOtp(_emailCtrl.text.trim());
      if (!mounted) return;
      setState(() => _challenge = ch);
      _startCooldown(45);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.retryAfterSeconds != null) {
        _startCooldown(e.retryAfterSeconds!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageFrom(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final ch = _challenge;
    if (ch == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .verifyOtp(ch.challengeId, _otpCtrl.text.trim());
      if (!mounted) return;
      final dest = widget.redirectTo;
      context.go((dest != null && dest.isNotEmpty) ? dest : '/explore');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.retryAfterSeconds != null) {
        _startCooldown(e.retryAfterSeconds!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageFrom(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _quickLogin(String email) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).quickMockLogin(email);
      if (!mounted) return;
      final dest = widget.redirectTo;
      context.go((dest != null && dest.isNotEmpty) ? dest : '/explore');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageFrom(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cfg = ref.watch(configProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.school, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đăng nhập sinh viên ĐH Sài Gòn',
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Xác thực bằng email để thuê và cho thuê đồ tại Cơ sở 1, Cơ sở 2 hoặc Cơ sở Chính.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    InlineAlertBanner(message: _error!, tone: StatusTone.error),
                    const SizedBox(height: 16),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _challenge == null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email sinh viên',
                                    hintText: 'mssv@sgu.edu.vn',
                                    helperText:
                                        'Sau khi xác thực sẽ quay lại trang bạn đang xem.',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _loading ? null : _sendOtp,
                                  child: Text(
                                    _loading ? 'Đang gửi mã...' : 'Gửi mã OTP',
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Nhập mã xác thực 6 số',
                                            style: tt.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Mã đã gửi tới ${_emailCtrl.text.trim()}',
                                            style: tt.bodySmall?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _loading
                                          ? null
                                          : () => setState(() {
                                                _challenge = null;
                                                _error = null;
                                              }),
                                      child: const Text('Đổi email'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _otpCtrl,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  style: tt.titleLarge?.copyWith(
                                    letterSpacing: 6,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Mã OTP (hiệu lực 5 phút)',
                                    helperText: cfg.useMock
                                        ? 'Mock: nhập 6 số bất kỳ (000000: lỗi mã, 999999: giới hạn tần suất)'
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _loading ? null : _verifyOtp,
                                  child: Text(
                                    _loading
                                        ? 'Đang xác nhận...'
                                        : 'Xác nhận và tiếp tục',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _resendSeconds > 0
                                          ? 'Gửi lại sau 00:${_resendSeconds.toString().padLeft(2, '0')}'
                                          : 'Chưa nhận được mã?',
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed:
                                          (_loading || _resendSeconds > 0)
                                              ? null
                                              : _sendOtp,
                                      child: const Text('Gửi lại mã'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (cfg.useMock) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: cs.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tài khoản mẫu (chế độ Mock)',
                              style: tt.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ActionChip(
                                  label: const Text('Minh (Đã duyệt)'),
                                  onPressed: _loading
                                      ? null
                                      : () => _quickLogin('minh@sgu.edu.vn'),
                                ),
                                ActionChip(
                                  label: const Text('Lan (Chủ đồ · 10k phí)'),
                                  onPressed: _loading
                                      ? null
                                      : () => _quickLogin('lan@sgu.edu.vn'),
                                ),
                                ActionChip(
                                  label: const Text('Huy (Chờ duyệt)'),
                                  onPressed: _loading
                                      ? null
                                      : () => _quickLogin('pending@sgu.edu.vn'),
                                ),
                                ActionChip(
                                  label: const Text('Quản trị viên'),
                                  onPressed: _loading
                                      ? null
                                      : () => _quickLogin('admin@sgu.edu.vn'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/explore'),
                    child: const Text('Xem danh sách món trước khi đăng nhập'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
