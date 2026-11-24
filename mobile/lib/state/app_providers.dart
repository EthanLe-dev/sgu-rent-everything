import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../models/case_fee.dart';
import '../models/listing.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/http_api_client.dart';
import '../services/mock_api_client.dart';

final initialConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig(
    useMock: AppConfig.defaultUseMock,
    apiBaseUrl: AppConfig.defaultBaseUrl,
  );
});

class ConfigNotifier extends Notifier<AppConfig> {
  @override
  AppConfig build() => ref.watch(initialConfigProvider);

  Future<void> updateConfig({bool? useMock, String? apiBaseUrl}) async {
    final next = state.copyWith(useMock: useMock, apiBaseUrl: apiBaseUrl);
    state = next;
    await next.save();
  }
}

final configProvider =
    NotifierProvider<ConfigNotifier, AppConfig>(ConfigNotifier.new);

final _mockClientSingleton = MockRentApiClient();

final apiClientProvider = Provider<RentApiClient>((ref) {
  final cfg = ref.watch(configProvider);
  if (cfg.useMock) return _mockClientSingleton;
  return HttpRentApiClient(baseUrl: cfg.apiBaseUrl);
});

class AuthNotifier extends AsyncNotifier<Me?> {
  @override
  Future<Me?> build() async {
    final api = ref.watch(apiClientProvider);
    if (api.accessToken == null || api.accessToken!.isEmpty) {
      return null;
    }
    try {
      return await api.getMe();
    } catch (_) {
      api.accessToken = null;
      return null;
    }
  }

  Future<OtpChallenge> requestOtp(String email) {
    return ref.read(apiClientProvider).requestOtp(email);
  }

  Future<Me> verifyOtp(String challengeId, String code) async {
    state = const AsyncLoading();
    final api = ref.read(apiClientProvider);
    try {
      final session = await api.verifyOtp(challengeId, code);
      state = AsyncData(session.me);
      ref.invalidate(notificationsProvider);
      return session.me;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Đăng nhập nhanh 1 chạm khi đang bật chế độ dữ liệu mẫu.
  Future<Me> quickMockLogin(String email) async {
    final api = ref.read(apiClientProvider);
    final challenge = await api.requestOtp(email);
    return verifyOtp(challenge.challengeId, '123456');
  }

  Future<Me> submitVerification({
    required String fullName,
    required String studentCode,
    required String className,
    required String faculty,
    required String displayName,
  }) async {
    final api = ref.read(apiClientProvider);
    final updated = await api.submitVerification(
      fullName: fullName,
      studentCode: studentCode,
      className: className,
      faculty: faculty,
      displayName: displayName,
    );
    state = AsyncData(updated);
    return updated;
  }

  Future<void> refreshMe() async {
    final api = ref.read(apiClientProvider);
    if (api.accessToken == null) {
      state = const AsyncData(null);
      return;
    }
    try {
      final me = await api.getMe();
      state = AsyncData(me);
    } catch (_) {
      api.accessToken = null;
      state = const AsyncData(null);
    }
  }

  Future<void> logout() async {
    final api = ref.read(apiClientProvider);
    await api.logout();
    state = const AsyncData(null);
    ref.invalidate(notificationsProvider);
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, Me?>(AuthNotifier.new);

final catalogOptionsProvider = FutureProvider<CatalogOptions>((ref) {
  return ref.watch(apiClientProvider).getCatalogOptions();
});

class NotificationsNotifier extends AsyncNotifier<List<Notice>> {
  @override
  Future<List<Notice>> build() async {
    final me = ref.watch(authProvider).value;
    if (me == null) return const [];
    final page = await ref.read(apiClientProvider).getNotifications();
    return page.items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(apiClientProvider).getNotifications();
      return page.items;
    });
  }

  Future<void> markRead(String id) async {
    final updated = await ref.read(apiClientProvider).markNotificationRead(id);
    final current = state.value ?? const [];
    state = AsyncData([
      for (final n in current) n.id == id ? updated : n,
    ]);
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<Notice>>(
  NotificationsNotifier.new,
);
