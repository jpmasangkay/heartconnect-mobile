class Payment {
  final String id;
  final String job;
  final String? milestoneId;
  final String payer;
  final String payee;
  final double amount;
  final String currency;
  final String status;
  final String? paymongoPaymentIntentId;
  final String? description;
  final String? createdAt;
  final String? updatedAt;

  Payment({
    required this.id,
    required this.job,
    this.milestoneId,
    required this.payer,
    required this.payee,
    required this.amount,
    this.currency = 'PHP',
    required this.status,
    this.paymongoPaymentIntentId,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount'];
    final amountNum = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw?.toString() ?? '') ?? 0.0;

    return Payment(
      id: json['_id'] ?? json['id'] ?? '',
      job: json['job']?.toString() ?? '',
      milestoneId: json['milestone'] is String
          ? json['milestone']
          : (json['milestone'] is Map ? json['milestone']['_id'] : null),
      payer: json['payer']?.toString() ?? '',
      payee: json['payee']?.toString() ?? '',
      amount: amountNum,
      currency: json['currency'] ?? 'PHP',
      status: json['status'] ?? 'pending',
      paymongoPaymentIntentId: json['paymongoPaymentIntentId'],
      description: json['description'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'job': job,
        'milestone': milestoneId,
        'payer': payer,
        'payee': payee,
        'amount': amount,
        'currency': currency,
        'status': status,
        'description': description,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}
