import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification.dart' as app;
import 'api_service.dart';
import 'socket_service.dart';

/// Real-time notification delivery via centralized Socket.IO.
class NotificationSocketService extends ApiService {
  NotificationSocketService._();
  static final NotificationSocketService instance = NotificationSocketService._();

  bool _disposed = false;
  bool _socketInitialized = false;
  bool _listenersRegistered = false;

  void Function(app.AppNotification notification)? _onNotification;
  void Function(int count)? _onUnreadCount;
  VoidCallback? _onConnect;
  VoidCallback? _onDisconnect;

  Future<void> initSocket({
    required void Function(app.AppNotification notification) onNotification,
    void Function(int count)? onUnreadCount,
    VoidCallback? onConnect,
    VoidCallback? onDisconnect,
  }) async {
    _onNotification = onNotification;
    _onUnreadCount = onUnreadCount;
    _onConnect = onConnect;
    _onDisconnect = onDisconnect;
    _disposed = false;

    await _connectSocket();
  }

  Future<void> _connectSocket() async {
    if (_disposed || _socketInitialized) return;
    _socketInitialized = true;

    final socketSvc = SocketService.instance;
    await socketSvc.initSocket();

    if (!_listenersRegistered) {
      _listenersRegistered = true;

      socketSvc.onConnect(() {
        _onConnect?.call();
      });

      socketSvc.onDisconnect(() {
        _onDisconnect?.call();
      });

      socketSvc.on('notification:new', (data) {
        debugPrint('Received notification:new event: $data');
        if (data != null && _onNotification != null) {
          try {
            final Map<String, dynamic> json;
            if (data is Map) {
              json = Map<String, dynamic>.from(data);
            } else {
              return;
            }
            final notif = app.AppNotification.fromJson(json);
            _onNotification!(notif);
          } catch (e) {
            debugPrint('Error parsing notification:new payload: $e');
          }
        }
      });

      socketSvc.on('notification:count', (data) {
        debugPrint('Received notification:count event: $data');
        if (data != null && _onUnreadCount != null) {
          try {
            int count;
            if (data is int) {
              count = data;
            } else if (data is Map) {
              count = (data['count'] ?? data['unreadCount'] ?? 0) as int;
            } else {
              count = int.tryParse(data.toString()) ?? 0;
            }
            _onUnreadCount!(count);
          } catch (e) {
            debugPrint('Error parsing notification:count payload: $e');
          }
        }
      });

      socketSvc.on('chat:unread', (data) {
        debugPrint('Received chat:unread event: $data');
      });
    }
  }

  bool get isConnected => SocketService.instance.isConnected;

  void disposeSocket() {
    _disposed = true;
    _socketInitialized = false;
    _onNotification = null;
    _onUnreadCount = null;
    _onConnect = null;
    _onDisconnect = null;
  }
}
