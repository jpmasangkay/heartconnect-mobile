import '../models/milestone.dart';
import 'api_service.dart';

class MilestoneService extends ApiService {
  MilestoneService._();
  static final MilestoneService instance = MilestoneService._();

  /// Create milestones for a job (client only).
  Future<List<Milestone>> create(
      String jobId, List<Map<String, dynamic>> milestones) async {
    final res = await dio.post('/milestones/$jobId', data: {
      'milestones': milestones,
    });
    final list = res.data is List ? res.data as List : <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => Milestone.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Get milestones for a job.
  Future<List<Milestone>> getForJob(String jobId) async {
    final res = await dio.get('/milestones/$jobId');
    final list = res.data is List ? res.data as List : <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => Milestone.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Student starts working on a funded milestone.
  Future<void> start(String id) async {
    await dio.patch('/milestones/$id/start');
  }

  /// Student submits a milestone for review.
  Future<void> submit(String id) async {
    await dio.patch('/milestones/$id/submit');
  }

  /// Client approves a submitted milestone.
  Future<void> approve(String id) async {
    await dio.patch('/milestones/$id/approve');
  }

  /// Either party disputes a milestone.
  Future<void> dispute(String id) async {
    await dio.patch('/milestones/$id/dispute');
  }
}
