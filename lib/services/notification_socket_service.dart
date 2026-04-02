import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification.dart' as app;
import 'api_service.dart';
import 'socket_service.dart';

/// Real-time notification delivery via centralized Socket.IO.
class NotificationSocketService extends ApiService {
  NotificationSocketService._();
  static final NotificationSocketService instance = NotificationSocketService._();

  final _notificationController = StreamController<app.AppNotification>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();
  final _connectController = StreamController<void>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();

  bool _listenersRegistered = false;

  Stream<app.AppNotification> get onNotification => _notificationController.stream;
  Stream<int> get onUnreadCount => _unreadCountController.stream;
  Stream<void> get onConnect => _connectController.stream;
  Stream<void> get onDisconnect => _disconnectController.stream;

  void setupSocketListeners() {
    if (_listenersRegistered) return;
    _listenersRegistered = true;

    final socketSvc = SocketService.instance;

    socketSvc.onConnect(() {
      _connectController.add(null);
    });

    socketSvc.onDisconnect(() {
      _disconnectController.add(null);
    });

    socketSvc.on('notification:new', (data) {
      debugPrint('Received notification:new event: $data');
      if (data != null) {
        try {
          final Map<String, dynamic> json;
          if (data is Map) {
            json = Map<String, dynamic>.from(data);
          } else {
            return;
          }
          final notif = app.AppNotification.fromJson(json);
          _notificationController.add(notif);
        } catch (e) {
          debugPrint('Error parsing notification:new payload: $e');
        }
      }
    });

    socketSvc.on('notification:count', (data) {
      debugPrint('Received notification:count event: $data');
      if (data != null) {
        try {
          int count;
          if (data is int) {
            count = data;
          } else if (data is Map) {
            count = (data['count'] ?? data['unreadCount'] ?? 0) as int;
          } else {
            count = int.tryParse(data.toString()) ?? 0;
          }
          _unreadCountController.add(count);
        } catch (e) {
          debugPrint('Error parsing notification:count payload: $e');
        }
      }
    });

    socketSvc.on('chat:unread', (data) {
      debugPrint('Received chat:unread event: $data');
    });
  }

  bool get isConnected => SocketService.instance.isConnected;

  void disposeSocket() {
    _notificationController.close();
    _unreadCountController.close();
    _connectController.close();
    _disconnectController.close();
    _listenersRegistered = false;
  }
}
