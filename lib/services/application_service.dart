import '../models/application.dart';
import 'api_service.dart';

class ApplicationService extends ApiService {
  Future<Application> apply(
      String jobId, String coverLetter, double proposedRate) async {
    final res = await dio.post('/jobs/$jobId/applications', data: {
      'coverLetter': coverLetter,
      'proposedRate': proposedRate,
    });
    return Application.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Application>> getForJob(String jobId) async {
    final res = await dio.get('/jobs/$jobId/applications');
    final data = res.data;
    final list = data is List ? data : (data['applications'] ?? data['data'] ?? data) as List;
    return list.whereType<Map>().map((e) => Application.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<Application>> getMyApplications() async {
    final res = await dio.get('/applications/my');
    final data = res.data;
    final list = data is List ? data : (data['applications'] ?? data['data'] ?? data) as List;
    return list.whereType<Map>().map((e) => Application.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Application> updateStatus(String id, String status) async {
    final res = await dio.patch('/applications/$id/status', data: {'status': status});
    return Application.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Application> withdraw(String id) async {
    final res = await dio.patch('/applications/$id/withdraw');
    return Application.fromJson(res.data as Map<String, dynamic>);
  }
}
