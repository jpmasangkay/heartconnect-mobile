import 'user.dart';
import 'job.dart';

class Message {
  final String id;
  final String conversationId;
  final User? sender;
  final String content;
  final bool read;
  final String createdAt;

  // File attachment fields
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final int? fileSize;

  Message({
    required this.id,
    required this.conversationId,
    this.sender,
    required this.content,
    required this.read,
    required this.createdAt,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.fileSize,
  });

  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;
  bool get isImage => fileType != null && fileType!.startsWith('image/');

  factory Message.fromJson(Map<String, dynamic> json) {
    User? sender;
    final senderData = json['sender'];
    if (senderData is Map<String, dynamic>) {
      sender = User.fromJson(senderData);
    }
    return Message(
      id: json['_id'] ?? json['id'] ?? '',
      conversationId: json['conversation'] ?? json['conversationId'] ?? '',
      sender: sender,
      content: json['content'] ?? '',
      read: json['read'] ?? false,
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      fileType: json['fileType'],
      fileSize: json['fileSize'] is num ? (json['fileSize'] as num).toInt() : null,
    );
  }
}

class Conversation {
  final String id;
  final List<User> participants;
  final Job? job;
  final Message? lastMessage;
  final int unreadCount;
  final String createdAt;
  final String updatedAt;

  Conversation({
    required this.id,
    required this.participants,
    this.job,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  User? otherParticipant(String myId) {
    if (participants.isEmpty) return null;
    final other = participants.where((p) => p.id != myId).toList();
    return other.isNotEmpty ? other.first : participants.first;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final participants = (json['participants'] as List? ?? [])
        .whereType<Map>()
        .map((e) => User.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    Job? job;
    final jobData = json['job'];
    if (jobData is Map<String, dynamic>) {
      job = Job.fromJson(jobData);
    }

    Message? lastMessage;
    final lastMsgData = json['lastMessage'];
    if (lastMsgData is Map<String, dynamic>) {
      lastMessage = Message.fromJson(lastMsgData);
    }

    return Conversation(
      id: json['_id'] ?? json['id'] ?? '',
      participants: participants,
      job: job,
      lastMessage: lastMessage,
      unreadCount: json['unreadCount'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }
}
