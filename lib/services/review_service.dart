import '../models/review.dart';
import '../models/job.dart';
import '../models/user.dart';
import 'api_service.dart';

class ReviewService extends ApiService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();
  Future<Review> createReview({
    required String jobId,
    required String revieweeId,
    required int rating,
    String comment = '',
  }) async {
    final res = await dio.post('/reviews', data: {
      'jobId': jobId,
      'revieweeId': revieweeId,
      'rating': rating,
      'comment': comment,
    });
    return Review.fromJson(res.data as Map<String, dynamic>);
  }

  Future<({List<Review> data, double avgRating, int total, int pages})> getUserReviews(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    final res = await dio.get('/reviews/user/$userId', queryParameters: {
      'page': page,
      'limit': limit,
    });
    final raw = res.data as Map<String, dynamic>;
    final list = (raw['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Review.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (
      data: list,
      avgRating: (raw['avgRating'] as num?)?.toDouble() ?? 0.0,
      total: raw['total'] as int? ?? 0,
      pages: raw['pages'] as int? ?? 1,
    );
  }

  Future<List<Review>> getJobReviews(String jobId) async {
    final res = await dio.get('/reviews/job/$jobId');
    final data = res.data;
    final list = data is List ? data : <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => Review.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<PendingReview>> getPendingReviews() async {
    final res = await dio.get('/reviews/pending');
    final rawData = res.data;
    final List<dynamic> list;
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map) {
      list = (rawData['data'] as List?) ?? [];
    } else {
      list = [];
    }
    return list.whereType<Map>().map((e) {
      final m = Map<String, dynamic>.from(e);
      Job? job;
      User? reviewee;
      if (m['job'] is Map) {
        job = Job.fromJson(Map<String, dynamic>.from(m['job']));
      }
      if (m['reviewee'] is Map) {
        reviewee = User.fromJson(Map<String, dynamic>.from(m['reviewee']));
      }
      return PendingReview(job: job, reviewee: reviewee);
    }).toList();
  }
}

class PendingReview {
  final Job? job;
  final User? reviewee;
  const PendingReview({this.job, this.reviewee});
}
