import 'user.dart';

class Job {
  final String id;
  final String title;
  final String description;
  final String category;
  final double budget;
  final String budgetType;
  final String deadline;
  final List<String> skills;
  final String status;
  final String locationType;
  final User? clientUser;
  final String? clientId;
  final int? applicationsCount;
  final String? createdAt;
  final String? updatedAt;

  Job({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.budget,
    required this.budgetType,
    required this.deadline,
    this.skills = const [],
    required this.status,
    this.locationType = 'remote',
    this.clientUser,
    this.clientId,
    this.applicationsCount,
    this.createdAt,
    this.updatedAt,
  });

  String get clientName => clientUser?.name ?? 'Unknown';
  String get effectiveClientId => clientId ?? clientUser?.id ?? '';

  /// Parses [skills] / [requiredSkills] from API (strings or `{name: ...}` objects).
  static List<String> skillsFromJson(dynamic raw) {
    if (raw == null) return [];
    if (raw is! List) return [];
    final out = <String>[];
    for (final e in raw) {
      if (e is String) {
        final t = e.trim();
        if (t.isNotEmpty) out.add(t);
      } else if (e is Map) {
        final n = e['name'] ?? e['skill'] ?? e['label'];
        if (n is String && n.trim().isNotEmpty) out.add(n.trim());
      }
    }
    return out;
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    User? clientUser;
    String? clientId;
    final clientData = json['client'];
    if (clientData is Map<String, dynamic>) {
      clientUser = User.fromJson(clientData);
    } else if (clientData is String) {
      clientId = clientData;
    }

    final budgetRaw = json['budget'];
    final budgetNum = budgetRaw is num
        ? budgetRaw.toDouble()
        : double.tryParse(budgetRaw?.toString() ?? '') ?? 0.0;

    return Job(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      budget: budgetNum,
      budgetType: json['budgetType'] ?? 'fixed',
      deadline: json['deadline'] ?? '',
      skills: skillsFromJson(json['skills'] ?? json['requiredSkills']),
      status: json['status'] ?? 'open',
      locationType: json['locationType'] ?? 'remote',
      clientUser: clientUser,
      clientId: clientId,
      applicationsCount: json['applicationsCount'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'title': title,
        'description': description,
        'category': category,
        'budget': budget,
        'budgetType': budgetType,
        'deadline': deadline,
        'skills': skills,
        'status': status,
        'locationType': locationType,
        'client': clientUser?.toJson() ?? clientId,
        'applicationsCount': applicationsCount,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  int get deadlineDays {
    try {
      final d = DateTime.parse(deadline);
      return d.difference(DateTime.now()).inDays;
    } catch (_) {
      return 0;
    }
  }
}
