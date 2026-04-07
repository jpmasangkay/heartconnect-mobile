import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification.dart' as app;
import 'api_service.dart';
import 'socket_service.dart';

/// Real-time notification delivery via centralized Socket.IO.
class NotificationSocketService extends ApiService {
  NotificationSocketService._();
  static final NotificationSocketService instance = NotificationSocketService._();

  StreamController<app.AppNotification> _notificationController = StreamController<app.AppNotification>.broadcast();
  StreamController<int> _unreadCountController = StreamController<int>.broadcast();
  StreamController<int> _chatUnreadController = StreamController<int>.broadcast();
  StreamController<void> _connectController = StreamController<void>.broadcast();
  StreamController<void> _disconnectController = StreamController<void>.broadcast();

  bool _listenersRegistered = false;

  Stream<app.AppNotification> get onNotification => _notificationController.stream;
  Stream<int> get onUnreadCount => _unreadCountController.stream;
  Stream<int> get onChatUnread => _chatUnreadController.stream;
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
      assert(() { debugPrint('Received notification:new event: $data'); return true; }());
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
          assert(() { debugPrint('Error parsing notification:new payload: $e'); return true; }());
        }
      }
    });

    socketSvc.on('notification:count', (data) {
      assert(() { debugPrint('Received notification:count event: $data'); return true; }());
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
          assert(() { debugPrint('Error parsing notification:count payload: $e'); return true; }());
        }
      }
    });

    socketSvc.on('chat:unread', (data) {
      assert(() { debugPrint('Received chat:unread event: $data'); return true; }());
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
          _chatUnreadController.add(count);
        } catch (e) {
          assert(() { debugPrint('Error parsing chat:unread payload: $e'); return true; }());
        }
      }
    });
  }

  bool get isConnected => SocketService.instance.isConnected;

  void disposeSocket() {
    _notificationController.close();
    _unreadCountController.close();
    _chatUnreadController.close();
    _connectController.close();
    _disconnectController.close();
    _listenersRegistered = false;
    _notificationController = StreamController<app.AppNotification>.broadcast();
    _unreadCountController = StreamController<int>.broadcast();
    _chatUnreadController = StreamController<int>.broadcast();
    _connectController = StreamController<void>.broadcast();
    _disconnectController = StreamController<void>.broadcast();
  }
}
