import 'api_service.dart';

class ReportService extends ApiService {
  ReportService._();
  static final ReportService instance = ReportService._();
  Future<void> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    await dio.post('/reports', data: {
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      if (details != null && details.isNotEmpty) 'details': details,
    });
  }
}
