import 'package:flutter/material.dart';
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
  bool _pushInitialized = false;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Initialize push notifications once we have the router
    if (!_pushInitialized) {
      _pushInitialized = true;
      PushNotificationService.instance.init(router: router);
    }

    return MaterialApp.router(
      title: 'HeartConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
