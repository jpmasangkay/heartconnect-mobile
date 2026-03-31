import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

/// Singleton service that displays native push-style notifications
/// (like Messenger) and navigates to the relevant screen on tap.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  GoRouter? _router;

  /// Must be called once at app startup (before runApp ideally).
  Future<void> init({required GoRouter router}) async {
    _router = router;

    // Android init settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS / macOS init settings
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap,
    );

    // Create the Android notification channel (heads-up, sound, vibrate)
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'heartconnect_notifications',
              'HeartConnect Notifications',
              description: 'Notifications for jobs, messages, and updates',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
              showBadge: true,
            ),
          );

      // Request notification permission (Android 13+)
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static const _shellPaths = {'/dashboard', '/jobs', '/chat', '/profile'};

  /// Called when the user taps a notification.
  void _onTap(NotificationResponse response) {
    var payload = response.payload;
    if (payload == null || payload.isEmpty || _router == null) return;

    // Strip full URLs to path only
    try {
      final uri = Uri.parse(payload);
      if (uri.hasScheme) payload = uri.path;
    } catch (_) {}

    // Strip trailing slashes
    payload = payload!.replaceAll(RegExp(r'/+$'), '');
    if (payload.isEmpty) return;

    debugPrint('Notification tapped → navigating to: $payload');
    try {
      // Shell routes need go(), detail routes need push()
      if (_shellPaths.contains(payload)) {
        _router!.go(payload);
      } else {
        _router!.push(payload);
      }
    } catch (e) {
      debugPrint('Navigation error on notification tap: $e');
    }
  }

  /// Display a native notification in the status bar.
  ///
  /// [id]      – unique int id (use hashCode of notification id)
  /// [title]   – notification title (bold text)
  /// [body]    – notification body / message
  /// [payload] – route to navigate to on tap (e.g. `/jobs/123`, `/chat/abc`)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'heartconnect_notifications',
      'HeartConnect Notifications',
      channelDescription: 'Notifications for jobs, messages, and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      // Messenger-style: heads-up pop-up notification
      fullScreenIntent: false,
      category: AndroidNotificationCategory.social,
      styleInformation: BigTextStyleInformation(body),
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Cancel a specific notification by id.
  Future<void> cancel(int id) => _plugin.cancel(id);

  /// Cancel all shown notifications.
  Future<void> cancelAll() => _plugin.cancelAll();
}
