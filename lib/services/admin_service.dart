import 'api_service.dart';

class AdminService extends ApiService {
  AdminService._();
  static final AdminService instance = AdminService._();

  Future<Map<String, dynamic>> getUsers({String search = '', int page = 1}) async {
    final res = await dio.get('/admin/users', queryParameters: {
      'search': search,
      'page': page,
    });
    return res.data;
  }

  Future<void> banUser(String userId, {String reason = 'Admin action'}) async {
    await dio.post('/admin/ban/$userId', data: {'reason': reason});
  }

  Future<void> unbanUser(String userId) async {
    await dio.post('/admin/unban/$userId');
  }

  Future<List<Map<String, dynamic>>> getPendingVerifications() async {
    final res = await dio.get('/verification/pending');
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<void> verifyUser(String userId, bool approve) async {
    await dio.patch('/verification/$userId/verify', data: {
      'action': approve ? 'approve' : 'reject'
    });
  }

  /// GET /api/reports?status=pending — admin: list pending reports (paginated)
  Future<List<Map<String, dynamic>>> getPendingReports() async {
    final res = await dio.get('/reports', queryParameters: {
      'status': 'pending',
      'limit': 50,
    });
    final data = res.data;
    if (data is Map && data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  /// PATCH /api/reports/:id — admin: resolve a report
  /// [action] must be 'reviewed' or 'dismissed'
  Future<Map<String, dynamic>> resolveReport(String reportId, String action) async {
    final res = await dio.patch('/reports/$reportId', data: {
      'action': action,
    });
    return Map<String, dynamic>.from(res.data ?? {});
  }
}
