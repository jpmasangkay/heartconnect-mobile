import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/conversation.dart';
import 'api_service.dart';
import 'socket_service.dart';

class ChatService extends ApiService {
  ChatService._();
  static final ChatService instance = ChatService._();

  bool _disposed = false;
  bool _socketInitialized = false;
  bool _listenersRegistered = false;

  Function(Message)? _onMessage;
  VoidCallback? _onConversationChanged;
  void Function(String userId, String conversationId, String? userName)? _onTyping;
  VoidCallback? _onConnect;
  VoidCallback? _onDisconnect;

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

      socketSvc.on('message_error', (data) {
        debugPrint('Socket message_error: $data');
      });

      socketSvc.on('conversation:new', (_) => _onConversationChanged?.call());
      socketSvc.on('conversation:hidden', (_) => _onConversationChanged?.call());
      socketSvc.on('conversation:deleted', (_) => _onConversationChanged?.call());
      socketSvc.on('messages:read', (_) => _onConversationChanged?.call());

      socketSvc.on('receive_message', (data) {
        if (data != null && _onMessage != null) {
          try {
            _onMessage!(Message.fromJson(Map<String, dynamic>.from(data)));
          } catch (e) {
            debugPrint('Error parsing message: $e');
          }
        }
      });

      socketSvc.on('typing', (data) {
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
    }
  }

  void joinRoom(String conversationId) {
    SocketService.instance.joinRoom(conversationId);
  }

  void leaveRoom(String conversationId) {
    SocketService.instance.leaveRoom(conversationId);
  }

  void sendMessage(String conversationId, String content) {
    SocketService.instance.emit('send_message', {
      'conversationId': conversationId,
      'content': content,
    });
  }

  void emitTyping(String conversationId, String userId) {
    SocketService.instance.emit('typing', {
      'conversationId': conversationId,
      'userId': userId,
    });
  }

  bool get isSocketConnected => SocketService.instance.isConnected;

  void disposeSocket() {
    _disposed = true;
    _socketInitialized = false;
    _onMessage = null;
    _onConversationChanged = null;
    _onTyping = null;
    _onConnect = null;
    _onDisconnect = null;
  }
}
