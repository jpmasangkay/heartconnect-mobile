import 'user.dart';

class Review {
  final String id;
  final String? jobId;
  final String? jobTitle;
  final User? reviewer;
  final User? reviewee;
  final int rating;
  final String comment;
  final String createdAt;

  Review({
    required this.id,
    this.jobId,
    this.jobTitle,
    this.reviewer,
    this.reviewee,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    User? reviewer;
    final reviewerData = json['reviewer'];
    if (reviewerData is Map<String, dynamic>) {
      reviewer = User.fromJson(reviewerData);
    }

    User? reviewee;
    final revieweeData = json['reviewee'];
    if (revieweeData is Map<String, dynamic>) {
      reviewee = User.fromJson(revieweeData);
    }

    String? jobId;
    String? jobTitle;
    final jobData = json['job'];
    if (jobData is Map<String, dynamic>) {
      jobId = jobData['_id'] ?? jobData['id'];
      jobTitle = jobData['title'];
    } else if (jobData is String) {
      jobId = jobData;
    }

    return Review(
      id: json['_id'] ?? json['id'] ?? '',
      jobId: jobId,
      jobTitle: jobTitle,
      reviewer: reviewer,
      reviewee: reviewee,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] ?? '',
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
