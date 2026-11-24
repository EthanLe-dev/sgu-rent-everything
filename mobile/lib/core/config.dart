import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cấu hình kết nối API và chế độ dữ liệu mẫu.
/// - Flutter Web mặc định dùng `/v1` cùng origin khi chạy API thật.
/// - Android mặc định dùng `http://10.0.2.2/v1` (có thể đổi ở màn Cá nhân).
class AppConfig {
  const AppConfig({
    required this.useMock,
    required this.apiBaseUrl,
  });

  final bool useMock;
  final String apiBaseUrl;

  static const _prefUseMock = 'sgu_rent_use_mock';
  static const _prefBaseUrl = 'sgu_rent_api_base_url';

  static String get defaultBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) return '/v1';
    return 'http://10.0.2.2/v1';
  }

  static bool get defaultUseMock =>
      const bool.fromEnvironment('USE_MOCK', defaultValue: true);

  static Future<AppConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final useMock = prefs.getBool(_prefUseMock) ?? defaultUseMock;
    final savedUrl = prefs.getString(_prefBaseUrl);
    return AppConfig(
      useMock: useMock,
      apiBaseUrl: (savedUrl != null && savedUrl.isNotEmpty)
          ? savedUrl
          : defaultBaseUrl,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefUseMock, useMock);
    await prefs.setString(_prefBaseUrl, apiBaseUrl);
  }

  AppConfig copyWith({bool? useMock, String? apiBaseUrl}) => AppConfig(
        useMock: useMock ?? this.useMock,
        apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      );
}
