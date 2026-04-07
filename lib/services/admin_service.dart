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
}
