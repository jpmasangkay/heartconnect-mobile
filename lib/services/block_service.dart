import '../models/user.dart';
import 'api_service.dart';

class BlockService extends ApiService {
  BlockService._();
  static final BlockService instance = BlockService._();
  Future<void> blockUser(String userId) async {
    await dio.post('/blocks/$userId');
  }

  Future<void> unblockUser(String userId) async {
    await dio.delete('/blocks/$userId');
  }

  Future<List<User>> getBlockedUsers() async {
    final res = await dio.get('/blocks');
    final data = res.data;
    final list = data is List ? data : <dynamic>[];
    return list.whereType<Map>().map((e) => User.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<bool> checkBlocked(String userId) async {
    try {
      final res = await dio.get('/blocks/check/$userId');
      return res.data['blocked'] == true;
    } catch (_) {
      return false;
    }
  }
}
