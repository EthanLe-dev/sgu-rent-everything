import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'router.dart';
import 'state/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await AppConfig.load();
  runApp(
    ProviderScope(
      overrides: [
        initialConfigProvider.overrideWithValue(config),
      ],
      child: const ThueDoSinhVienApp(),
    ),
  );
}

class ThueDoSinhVienApp extends ConsumerWidget {
  const ThueDoSinhVienApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Thuê Đồ Sinh Viên',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
