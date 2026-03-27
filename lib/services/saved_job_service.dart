import '../models/job.dart';
import 'api_service.dart';

class SavedJobService extends ApiService {
  Future<({List<Job> data, int total, int pages})> getSavedJobs({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await dio.get('/saved-jobs', queryParameters: {
      'page': page,
      'limit': limit,
    });
    final raw = res.data as Map<String, dynamic>;
    final list = <Job>[];
    for (final item in (raw['data'] as List? ?? [])) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final jobData = m['job'];
      if (jobData is Map<String, dynamic>) {
        try {
          list.add(Job.fromJson(jobData));
        } catch (_) {}
      }
    }
    return (
      data: list,
      total: raw['total'] as int? ?? 0,
      pages: raw['pages'] as int? ?? 1,
    );
  }

  Future<bool> checkSaved(String jobId) async {
    try {
      final res = await dio.get('/saved-jobs/check/$jobId');
      return res.data['saved'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveJob(String jobId) async {
    await dio.post('/saved-jobs', data: {'jobId': jobId});
  }

  Future<void> unsaveJob(String jobId) async {
    await dio.delete('/saved-jobs/$jobId');
  }
}
