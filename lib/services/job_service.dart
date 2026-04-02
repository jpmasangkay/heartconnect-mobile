import 'dart:async';
import '../models/job.dart';
import 'api_service.dart';
import 'socket_service.dart';

int _readInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v.toString()) ?? fallback;
}

class JobService extends ApiService {
  JobService._();
  static final JobService instance = JobService._();

  Map<String, dynamic> _unwrapJobPayload(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      if (raw['_id'] != null || raw['id'] != null) return raw;
      final job = raw['job'];
      if (job is Map<String, dynamic>) return job;
      final data = raw['data'];
      if (data is Map<String, dynamic>) return data;
    }
    throw FormatException('Expected job JSON object, got ${raw.runtimeType}');
  }

  Future<({List<Job> jobs, int total, int pages})> getJobs({
    String? search,
    String? category,
    double? budgetMin,
    double? budgetMax,
    String? skills,
    String? deadlineBefore,
    String? deadlineAfter,
    String? locationType,
    int page = 1,
    int limit = 9,
  }) async {
    final res = await dio.get('/jobs', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null && category.isNotEmpty) 'category': category,
      if (budgetMin != null) 'budgetMin': budgetMin,
      if (budgetMax != null) 'budgetMax': budgetMax,
      if (skills != null && skills.isNotEmpty) 'skills': skills,
      if (deadlineBefore != null) 'deadlineBefore': deadlineBefore,
      if (deadlineAfter != null) 'deadlineAfter': deadlineAfter,
      if (locationType != null && locationType.isNotEmpty) 'locationType': locationType,
      'page': page,
      'limit': limit,
    });
    final raw = res.data;
    if (raw is! Map) {
      throw FormatException('Expected job list JSON object, got ${raw.runtimeType}');
    }
    final data = Map<String, dynamic>.from(raw);
    final listRaw = data['data'] ?? data['jobs'];
    final list = listRaw is List ? listRaw : <dynamic>[];

    final jobs = <Job>[];
    for (final item in list) {
      if (item is! Map) continue;
      try {
        jobs.add(Job.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        /* skip malformed row so the rest of the board still loads */
      }
    }

    return (
      jobs: jobs,
      total: _readInt(data['total']),
      pages: _readInt(data['pages'], 1).clamp(1, 999999),
    );
  }

  Future<Job> getJob(String id) async {
    final res = await dio.get('/jobs/$id');
    return Job.fromJson(_unwrapJobPayload(res.data));
  }

  Future<Job> createJob(Map<String, dynamic> data) async {
    final res = await dio.post('/jobs', data: data);
    return Job.fromJson(_unwrapJobPayload(res.data));
  }

  Future<Job> updateJob(String id, Map<String, dynamic> data) async {
    final res = await dio.put('/jobs/$id', data: data);
    return Job.fromJson(_unwrapJobPayload(res.data));
  }

  Future<void> deleteJob(String id) async {
    await dio.delete('/jobs/$id');
  }

  Future<Job> closeJob(String id) async {
    final res = await dio.patch('/jobs/$id/close');
    return Job.fromJson(_unwrapJobPayload(res.data));
  }

  Future<Job> completeJob(String id) async {
    final res = await dio.patch('/jobs/$id/complete');
    return Job.fromJson(_unwrapJobPayload(res.data));
  }

  Future<List<Job>> getMyJobs() async {
    final res = await dio.get('/jobs/my');
    final data = res.data;
    final list = data is List ? data : (data['jobs'] ?? data['data'] ?? []) as List;
    return list.whereType<Map>().map((e) => Job.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<String>> getCategories() async {
    try {
      final res = await dio.get('/jobs/categories');
      final data = res.data as Map<String, dynamic>;
      return List<String>.from(data['categories'] ?? []);
    } catch (_) {
      return [];
    }
  }

  // ── Socket ───────────────────────────────────────────────────────────────

  bool _listenersRegistered = false;
  final _newJobController = StreamController<void>.broadcast();
  Stream<void> get onNewJob => _newJobController.stream;

  void setupSocketListeners() {
    if (_listenersRegistered) return;
    _listenersRegistered = true;
    
    final socketSvc = SocketService.instance;

    socketSvc.on('job:new', (_) {
      _newJobController.add(null);
    });
    
    socketSvc.on('new_job', (_) {
      _newJobController.add(null);
    });
  }

  void disposeSocket() {
    _newJobController.close();
    _listenersRegistered = false;
  }
}
