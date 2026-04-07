import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/conversation.dart';
import 'api_service.dart';
import 'socket_service.dart';

class ChatService extends ApiService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final _messageController = StreamController<Message>.broadcast();
  final _conversationChangedController = StreamController<void>.broadcast();
  final _typingController = StreamController<({String userId, String conversationId, String? userName})>.broadcast();
  final _connectController = StreamController<void>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();

  Stream<Message> get onMessage => _messageController.stream;
  Stream<void> get onConversationChanged => _conversationChangedController.stream;
  Stream<({String userId, String conversationId, String? userName})> get onTyping => _typingController.stream;
  Stream<void> get onConnect => _connectController.stream;
  Stream<void> get onDisconnect => _disconnectController.stream;

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

  Future<Message> sendMessageWithFile({
    required String conversationId,
    String content = '',
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    final formData = FormData.fromMap({
      'content': content,
    });

    if (filePath != null) {
      formData.files.add(MapEntry(
        'file',
        await MultipartFile.fromFile(filePath, filename: fileName ?? filePath.split('/').last),
      ));
    } else if (fileBytes != null && fileName != null) {
      formData.files.add(MapEntry(
        'file',
        MultipartFile.fromBytes(fileBytes, filename: fileName),
      ));
    }

    final res = await dio.post('/conversations/$conversationId/messages', data: formData);
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

  bool _listenersRegistered = false;

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

    socketSvc.on('message_error', (data) {
      debugPrint('Socket message_error: $data');
    });

    socketSvc.on('conversation:new', (_) => _conversationChangedController.add(null));
    socketSvc.on('conversation:hidden', (_) => _conversationChangedController.add(null));
    socketSvc.on('conversation:deleted', (_) => _conversationChangedController.add(null));
    socketSvc.on('messages:read', (_) => _conversationChangedController.add(null));

    socketSvc.on('receive_message', (data) {
      if (data != null) {
        try {
          _messageController.add(Message.fromJson(Map<String, dynamic>.from(data)));
        } catch (e) {
          debugPrint('Error parsing message: $e');
        }
      }
    });

    socketSvc.on('typing', (data) {
      if (data == null) return;
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
        _typingController.add((userId: userId, conversationId: convoId, userName: userName));
      }
    });
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
    _messageController.close();
    _conversationChangedController.close();
    _typingController.close();
    _connectController.close();
    _disconnectController.close();
    _listenersRegistered = false;
  }
}
