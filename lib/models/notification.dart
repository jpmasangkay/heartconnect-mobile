class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final String? link;
  final bool read;
  final String? relatedJob;
  final String? relatedApplication;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.link,
    required this.read,
    this.relatedJob,
    this.relatedApplication,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      link: json['link'],
      read: json['read'] ?? false,
      relatedJob: json['relatedJob'] is Map
          ? json['relatedJob']['_id']
          : json['relatedJob'],
      relatedApplication: json['relatedApplication'] is Map
          ? json['relatedApplication']['_id']
          : json['relatedApplication'],
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      link: link,
      read: read ?? this.read,
      relatedJob: relatedJob,
      relatedApplication: relatedApplication,
      createdAt: createdAt,
    );
  }
}
