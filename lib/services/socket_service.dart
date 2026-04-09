import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_service.dart';

/// Centralized Socket.IO service to prevent multiple connections.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  bool _disposed = false;
  String? _currentToken;

  final Set<String> _joinedRooms = {};
  
  final List<VoidCallback> _onConnectListeners = [];
  final List<VoidCallback> _onDisconnectListeners = [];
  
  final Map<String, List<Function(dynamic)>> _eventListeners = {};

  io.Socket? get socket => _socket;
  bool get isConnected => _socket?.connected ?? false;

  /// Initializes the socket, or reconnects if the auth token has changed.
  Future<void> initSocket() async {
    _disposed = false;
    final token = await ApiService.getToken();
    if (token == null) return;

    if (_socket != null && _currentToken == token) return;

    // Token changed (re-login) — tear down the old socket first.
    if (_socket != null && _currentToken != token) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    _currentToken = token;

    _socket = io.io(
      ApiService.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(50)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(15000)
          .setTimeout(10000)
          .setAuth({'token': token, 'platform': ApiService.platform})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _socket!.onConnect((_) {
      if (_disposed) return;
      assert(() { debugPrint('Master Socket connected'); return true; }());
      for (final room in _joinedRooms) {
        _socket?.emit('join_room', room);
      }
      for (final listener in List.of(_onConnectListeners)) {
        listener();
      }
    });

    _socket!.onDisconnect((reason) {
      if (_disposed) return;
      assert(() { debugPrint('Master Socket disconnected: $reason'); return true; }());
      for (final listener in List.of(_onDisconnectListeners)) {
        listener();
      }
    });

    _socket!.onConnectError((err) {
      if (_disposed) return;
      assert(() { debugPrint('Master Socket connect error: $err'); return true; }());
    });

    _socket!.onError((err) {
      if (_disposed) return;
      assert(() { debugPrint('Master Socket error: $err'); return true; }());
    });

    for (final event in _eventListeners.keys) {
      _bindEventToSocket(event);
    }

    _socket!.connect();
  }

  void _bindEventToSocket(String event) {
    if (_socket == null) return;
    if (_socket!.hasListeners(event)) return;
    
    _socket!.on(event, (data) {
      final listeners = _eventListeners[event]?.toList() ?? [];
      for (final listener in listeners) {
        try {
          listener(data);
        } catch (e) {
          assert(() { debugPrint('Error in socket listener for $event: $e'); return true; }());
        }
      }
    });
  }

  void onDisconnect(VoidCallback listener) {
    _onDisconnectListeners.add(listener);
  }

  void onConnect(VoidCallback listener) {
    _onConnectListeners.add(listener);
  }

  void on(String event, Function(dynamic) callback) {
    _eventListeners.putIfAbsent(event, () => []).add(callback);
    _bindEventToSocket(event);
  }

  void off(String event, Function(dynamic) callback) {
    _eventListeners[event]?.remove(callback);
    if (_eventListeners[event]?.isEmpty ?? false) {
      _eventListeners.remove(event);
      _socket?.off(event);
    }
  }

  void joinRoom(String roomId) {
    _joinedRooms.add(roomId);
    if (isConnected) {
      _socket?.emit('join_room', roomId);
    }
  }

  void leaveRoom(String roomId) {
    _joinedRooms.remove(roomId);
    if (isConnected) {
      _socket?.emit('leave_room', roomId);
    }
  }

  void emit(String event, [dynamic data]) {
    if (isConnected) {
      _socket?.emit(event, data);
    }
  }

  void dispose() {
    _disposed = true;
    _onConnectListeners.clear();
    _onDisconnectListeners.clear();
    _eventListeners.clear();
    _joinedRooms.clear();
    _currentToken = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
