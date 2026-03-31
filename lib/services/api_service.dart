import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

/// HTTP API client for the mobile app.
///
/// **Auth model:** Bearer JWT in `Authorization` header. This client stores the
/// token in [FlutterSecureStorage]. The API returns `token` in JSON from login/register;
/// it does not rely on cookies. A web SPA should use the same Bearer flow (store the
/// token per your security policy) and send `VITE_API_URL` / `VITE_SOCKET_URL` via env.
class ApiService {
  static const String platform = 'mobile';

  static VoidCallback? onAuthExpired;

  static String get baseUrl => AppConfig.apiBaseUrl;

  static String get socketUrl => AppConfig.socketUrl;

  static final FlutterSecureStorage _sharedStorage = const FlutterSecureStorage();
  static String? _cachedToken;
  
  static final Dio _sharedDio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'X-Platform': platform,
    },
  ))..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      _cachedToken ??= await _sharedStorage.read(key: 'jwt_token');
      if (_cachedToken != null) {
        options.headers['Authorization'] = 'Bearer $_cachedToken';
      }
      return handler.next(options);
    },
    onError: (DioException e, handler) {
      if (e.response?.statusCode == 401) {
        debugPrint('API 401: token expired or invalidated');
        clearToken();
        onAuthExpired?.call();
      }
      return handler.next(e);
    },
  ));

  Dio get dio => _sharedDio;
  FlutterSecureStorage get storage => _sharedStorage;

  static Future<String?> getToken() async {
    _cachedToken ??= await _sharedStorage.read(key: 'jwt_token');
    return _cachedToken;
  }

  static Future<void> setToken(String token) async {
    _cachedToken = token;
    await _sharedStorage.write(key: 'jwt_token', value: token);
  }

  static Future<void> clearToken() async {
    _cachedToken = null;
    await _sharedStorage.delete(key: 'jwt_token');
  }

  String extractError(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Server did not respond in time. Check VITE_API_URL / API_BASE_URL / API_HOST ($baseUrl) and that the backend is running.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Cannot reach server at $baseUrl. Set --dart-define=VITE_API_URL=... (or API_BASE_URL, or API_HOST for LAN dev).';
      }
      if (e.response?.statusCode == 401) {
        return 'Session expired. Please log in again.';
      }
      if (e.response?.statusCode == 429) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          return data['message'].toString();
        }
        return 'Too many attempts right now. Please wait a minute and try again.';
      }
      final data = e.response?.data;
      if (data is Map) {
        if (data['errors'] is List) {
          return (data['errors'] as List).join(' · ');
        }
        return data['message']?.toString() ?? e.message ?? 'Request failed';
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }
}
