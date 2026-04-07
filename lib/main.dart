import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'services/push_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: HeartConnectApp()));
}

class HeartConnectApp extends ConsumerStatefulWidget {
  const HeartConnectApp({super.key});

  @override
  ConsumerState<HeartConnectApp> createState() => _HeartConnectAppState();
}

class _HeartConnectAppState extends ConsumerState<HeartConnectApp> {
  @override
  void initState() {
    super.initState();
    final isFlutterTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isFlutterTest) {
      // Defer until the first frame so the router provider is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final router = ref.read(routerProvider);
        PushNotificationService.instance.init(router: router);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'HeartConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
