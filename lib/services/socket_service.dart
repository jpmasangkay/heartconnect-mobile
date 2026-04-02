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

  final Set<String> _joinedRooms = {};
  
  // Callback registries
  final List<VoidCallback> _onConnectListeners = [];
  final List<VoidCallback> _onDisconnectListeners = [];
  
  // Event listeners map: eventName -> list of callbacks
  final Map<String, List<Function(dynamic)>> _eventListeners = {};

  io.Socket? get socket => _socket;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> initSocket() async {
    _disposed = false;
    final token = await ApiService.getToken();
    if (token == null) return;

    if (_socket != null) return;

    _socket = io.io(
      ApiService.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(300)
          .setReconnectionDelayMax(8000)
          .setTimeout(8000)
          .setAuth({'token': token, 'platform': ApiService.platform})
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Master Socket connected');
      for (final room in _joinedRooms) {
        _socket?.emit('join_room', room);
      }
      for (final listener in _onConnectListeners) {
        listener();
      }
    });

    _socket!.onDisconnect((reason) {
      debugPrint('Master Socket disconnected: $reason');
      for (final listener in _onDisconnectListeners) {
        listener();
      }
    });

    _socket!.onConnectError((err) {
      debugPrint('Master Socket connect error: $err');
    });

    _socket!.onError((err) {
      debugPrint('Master Socket error: $err');
    });

    // We use a wildcard catch-all approach if possible, but package socket_io_client 
    // requires binding per event. We'll bind listeners dynamically when registered.
    for (final event in _eventListeners.keys) {
      _bindEventToSocket(event);
    }

    _socket!.connect();
  }

  void _bindEventToSocket(String event) {
    if (_socket == null) return;
    // Don't bind twice
    if (_socket!.hasListeners(event)) return;
    
    _socket!.on(event, (data) {
      final listeners = _eventListeners[event]?.toList() ?? [];
      for (final listener in listeners) {
        try {
          listener(data);
        } catch (e) {
          debugPrint('Error in socket listener for $event: $e');
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
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
