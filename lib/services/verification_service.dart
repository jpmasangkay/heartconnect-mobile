import 'dart:io';
import 'package:dio/dio.dart';
import 'api_service.dart';

class VerificationService extends ApiService {
  Future<Map<String, dynamic>> requestSchoolEmail() async {
    final res = await dio.post('/verification/request', data: {
      'method': 'school_email',
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadId(File file) async {
    final formData = FormData.fromMap({
      'idPhoto': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split(Platform.pathSeparator).last,
      ),
    });
    final res = await dio.post('/verification/request-upload', data: formData);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStatus() async {
    final res = await dio.get('/verification/status');
    return res.data as Map<String, dynamic>;
  }
}
