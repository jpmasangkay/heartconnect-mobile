import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/conversation.dart';
import 'api_service.dart';

class ChatService extends ApiService {
  io.Socket? _socket;
  Timer? _reconnectTimer;
  bool _disposed = false;

  Function(Message)? _onMessage;
  VoidCallback? _onConversationChanged;
  void Function(String userId, String conversationId, String? userName)? _onTyping;
  VoidCallback? _onConnect;
  VoidCallback? _onDisconnect;

  final Set<String> _joinedRooms = {};

  // ── REST ──────────────────────────────────────────────────────────────────

  Future<List<Conversation>> getConversations() async {
    final res = await dio.get('/conversations');
    final data = res.data;
    // Backend returns either a List OR a paging object: { data, total, pages, page }.
    final list = data is List
        ? data
        : (data is Map
            ? ((data['data'] ?? data['conversations'] ?? const <dynamic>[]) as List)
            : const <dynamic>[]);
    return list
        .whereType<Map>()
        .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Conversation> getOrCreate(String jobId, String participantId) async {
    final res = await dio.post('/conversations', data: {
      'jobId': jobId,
      'participantId': participantId,
    });
    return Conversation.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<Message>> getMessages(String conversationId) async {
    final res = await dio.get('/conversations/$conversationId/messages');
    final data = res.data;
    // Backend returns either a List OR a paging object: { data, total, pages, page }.
    final list = data is List
        ? data
        : (data is Map
            ? ((data['data'] ?? data['messages'] ?? const <dynamic>[]) as List)
            : const <dynamic>[]);
    return list
        .whereType<Map>()
        .map((e) => Message.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Message> sendMessageRest(String conversationId, String content) async {
    final res = await dio.post('/conversations/$conversationId/messages', data: {'content': content});
    return Message.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> markRead(String conversationId) async {
    try {
      await dio.patch('/conversations/$conversationId/read');
    } catch (_) {}
  }

  Future<int> getUnreadCount() async {
    try {
      final res = await dio.get('/conversations/unread');
      return (res.data['count'] ?? 0) as int;
    } catch (_) {
      return 0;
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    await dio.delete('/conversations/$conversationId');
  }

  // ── Socket ───────────────────────────────────────────────────────────────

  Future<void> initSocket({
    required Function(Message) onMessage,
    required void Function(String userId, String conversationId, String? userName) onTyping,
    VoidCallback? onConversationChanged,
    VoidCallback? onConnect,
    VoidCallback? onDisconnect,
  }) async {
    _onMessage = onMessage;
    _onTyping = onTyping;
    _onConversationChanged = onConversationChanged;
    _onConnect = onConnect;
    _onDisconnect = onDisconnect;
    _disposed = false;

    await _connectSocket();
  }

  Future<void> _connectSocket() async {
    final token = await storage.read(key: 'jwt_token');
    if (token == null || _disposed) return;

    _socket?.disconnect();
    _socket?.dispose();

    _socket = io.io(
      ApiService.socketUrl,
      io.OptionBuilder()
          // Some Android/proxy setups fail with websocket-only. Allow polling fallback.
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          // Use built-in reconnection to avoid rapid manual connect/disconnect loops.
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(300)
          .setReconnectionDelayMax(8000)
          .setTimeout(8000)
          .setAuth({'token': token, 'platform': ApiService.platform})
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Socket connected');
      _reconnectTimer?.cancel();
      for (final room in _joinedRooms) {
        _socket?.emit('join_room', room);
      }
      _onConnect?.call();
    });

    _socket!.onDisconnect((reason) {
      debugPrint('Socket disconnected: $reason');
      _onDisconnect?.call();
    });

    _socket!.onConnectError((err) {
      debugPrint('Socket connect error: $err');
    });

    _socket!.onError((err) {
      debugPrint('Socket error: $err');
    });

    _socket!.on('message_error', (data) {
      // Server can emit message_error when blocked/spam-limited/etc.
      debugPrint('Socket message_error: $data');
    });

    // Conversation lifecycle events (server emits these to user rooms)
    _socket!.on('conversation:new', (_) => _onConversationChanged?.call());
    _socket!.on('conversation:hidden', (_) => _onConversationChanged?.call());
    _socket!.on('conversation:deleted', (_) => _onConversationChanged?.call());
    _socket!.on('messages:read', (_) => _onConversationChanged?.call());

    _socket!.on('receive_message', (data) {
      if (data != null && _onMessage != null) {
        try {
          _onMessage!(Message.fromJson(Map<String, dynamic>.from(data)));
        } catch (e) {
          debugPrint('Error parsing message: $e');
        }
      }
    });

    _socket!.on('typing', (data) {
      if (data == null || _onTyping == null) return;
      String? userId;
      String? convoId;
      String? userName;
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        userId = m['userId']?.toString() ?? m['user_id']?.toString();
        convoId = m['conversationId']?.toString() ?? m['conversation_id']?.toString();
        userName = m['userName']?.toString() ??
            m['user_name']?.toString() ??
            m['name']?.toString() ??
            m['displayName']?.toString();
      } else if (data is String) {
        final parts = data.split(':');
        if (parts.length >= 2) {
          userId = parts[0];
          convoId = parts[1];
          if (parts.length > 2) userName = parts.sublist(2).join(':');
        }
      }
      if (userId != null &&
          convoId != null &&
          userId.isNotEmpty &&
          convoId.isNotEmpty) {
        _onTyping!(userId, convoId, userName);
      }
    });

    _socket!.connect();
  }



  void joinRoom(String conversationId) {
    _joinedRooms.add(conversationId);
    _socket?.emit('join_room', conversationId);
  }

  void leaveRoom(String conversationId) {
    _joinedRooms.remove(conversationId);
  }

  void sendMessage(String conversationId, String content) {
    if (_socket?.connected == true) {
      _socket!.emit('send_message', {
        'conversationId': conversationId,
        'content': content,
      });
    }
  }

  void emitTyping(String conversationId, String userId) {
    _socket?.emit('typing', {
      'conversationId': conversationId,
      'userId': userId,
    });
  }

  bool get isSocketConnected => _socket?.connected ?? false;

  void disposeSocket() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _joinedRooms.clear();
    _onMessage = null;
    _onConversationChanged = null;
    _onTyping = null;
    _onConnect = null;
    _onDisconnect = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
