import '../models/notification.dart' as app;
import 'api_service.dart';

class NotificationService extends ApiService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  Future<({List<app.AppNotification> data, int total, int pages})> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await dio.get('/notifications', queryParameters: {
      'page': page,
      'limit': limit,
    });
    final raw = res.data as Map<String, dynamic>;
    final list = (raw['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => app.AppNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (
      data: list,
      total: raw['total'] as int? ?? 0,
      pages: raw['pages'] as int? ?? 1,
    );
  }

  Future<int> getUnreadCount() async {
    try {
      final res = await dio.get('/notifications/unread-count');
      return (res.data['count'] ?? 0) as int;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markAsRead(String id) async {
    await dio.patch('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await dio.patch('/notifications/read-all');
  }

  Future<int> deleteReadNotifications() async {
    final res = await dio.delete('/notifications/read');
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return (data['deleted'] as int?) ?? 0;
    }
    return 0;
  }
}
