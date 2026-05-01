import '../models/payment.dart';
import 'api_service.dart';

class PaymentService extends ApiService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  /// Create a payment intent for a milestone (client only).
  Future<Map<String, dynamic>> createIntent(String milestoneId, String returnUrl) async {
    final res = await dio.post('/payments/create-intent', data: {
      'milestoneId': milestoneId,
      'returnUrl': returnUrl,
    });
    return Map<String, dynamic>.from(res.data);
  }

  /// Get all payments for a job.
  Future<List<Payment>> getForJob(String jobId) async {
    final res = await dio.get('/payments/job/$jobId');
    final list = res.data is List ? res.data as List : <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => Payment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Release escrow funds (client approves).
  Future<void> release(String paymentId) async {
    await dio.post('/payments/$paymentId/release');
  }

  /// Refund escrowed funds.
  Future<void> refund(String paymentId) async {
    await dio.post('/payments/$paymentId/refund');
  }
}
