import 'user.dart';
import 'job.dart';

class Application {
  final String id;
  final Job? job;
  final User? applicant;
  final String coverLetter;
  final double proposedRate;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  Application({
    required this.id,
    this.job,
    this.applicant,
    required this.coverLetter,
    required this.proposedRate,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory Application.fromJson(Map<String, dynamic> json) {
    Job? job;
    final jobData = json['job'];
    if (jobData is Map<String, dynamic>) {
      job = Job.fromJson(jobData);
    }

    User? applicant;
    final applicantData = json['applicant'];
    if (applicantData is Map<String, dynamic>) {
      applicant = User.fromJson(applicantData);
    }

    return Application(
      id: json['_id'] ?? json['id'] ?? '',
      job: job,
      applicant: applicant,
      coverLetter: json['coverLetter'] ?? '',
      proposedRate: (json['proposedRate'] is num)
          ? (json['proposedRate'] as num).toDouble()
          : double.tryParse(json['proposedRate']?.toString() ?? '') ?? 0.0,
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }
}
