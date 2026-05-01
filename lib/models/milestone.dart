class Milestone {
  final String id;
  final String job;
  final String title;
  final String? description;
  final double amount;
  final int order;
  final String status;
  final String? paymentId;
  final String? dueDate;
  final String? createdAt;
  final String? updatedAt;

  Milestone({
    required this.id,
    required this.job,
    required this.title,
    this.description,
    required this.amount,
    required this.order,
    required this.status,
    this.paymentId,
    this.dueDate,
    this.createdAt,
    this.updatedAt,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount'];
    final amountNum = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw?.toString() ?? '') ?? 0.0;

    return Milestone(
      id: json['_id'] ?? json['id'] ?? '',
      job: json['job']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      amount: amountNum,
      order: json['order'] is int ? json['order'] : 0,
      status: json['status'] ?? 'pending',
      paymentId: json['payment'] is String
          ? json['payment']
          : (json['payment'] is Map ? json['payment']['_id'] : null),
      dueDate: json['dueDate'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'job': job,
        'title': title,
        'description': description,
        'amount': amount,
        'order': order,
        'status': status,
        'payment': paymentId,
        'dueDate': dueDate,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}
