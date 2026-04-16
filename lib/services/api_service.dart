import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

/// Maximum file size allowed for uploads (10 MB).
const int kMaxUploadBytes = 10 * 1024 * 1024;

/// Allowed MIME-type prefixes for chat file attachments.
const Set<String> kAllowedUploadExtensions = {
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic',
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
  'txt', 'csv', 'zip', 'rar',
};

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
  
  /// Paths that should never carry an Authorization header.
  static const _unauthPaths = {'/auth/login', '/auth/register', '/auth/forgot-password', '/auth/reset-password'};

  static bool _isUnauthPath(String path) =>
      _unauthPaths.any((p) => path.endsWith(p));

  static final Dio _sharedDio = Dio(BaseOptions(
    baseUrl: baseUrl,
    // Render free-tier cold-starts can take 50+ seconds; 60 s gives headroom.
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 60),
    headers: {
      'Content-Type': 'application/json',
      'X-Platform': platform,
    },
  ))..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      // Some deployments apply origin allowlists at the app layer (not only via
      // browser CORS). Mobile HTTP clients don't send an Origin header by
      // default, so optionally provide a configured client origin.
      final origin = AppConfig.clientOrigin;
      if (origin.isNotEmpty && options.headers['Origin'] == null) {
        options.headers['Origin'] = origin;
        options.headers['Referer'] = '$origin/';
      }

      // Use print (not debugPrint) so it always shows in logs.
      if (kDebugMode) {
        print(
          'API REQ ${options.method} ${options.uri} | Origin=${options.headers['Origin']}',
        );
      }

      // Don't attach a Bearer token to public auth endpoints.
      if (!_isUnauthPath(options.path)) {
        _cachedToken ??= await _sharedStorage.read(key: 'jwt_token');
        if (_cachedToken != null) {
          options.headers['Authorization'] = 'Bearer $_cachedToken';
        }
      }
      return handler.next(options);
    },
    onError: (DioException e, handler) {
      if (kDebugMode) {
        final req = e.requestOptions;
        print(
          'API ERR ${e.response?.statusCode ?? '-'} ${req.method} ${req.uri} '
          '| Origin=${req.headers['Origin']} '
          '| Data=${e.response?.data}',
        );
      }
      if (e.response?.statusCode == 401) {
        final path = e.requestOptions.path;
        // Only trigger session-expiry for authenticated endpoints;
        // skip login/register (wrong creds) and /auth/me (init probe).
        if (!_isUnauthPath(path) && !path.endsWith('/me')) {
          assert(() { debugPrint('API 401: token expired or invalidated'); return true; }());
          clearToken();
          onAuthExpired?.call();
        }
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

  /// Patterns that indicate a raw server-side JavaScript / Node.js crash message
  /// that should never be shown verbatim to the user.
  static final _serverCrashPattern = RegExp(
    r'Cannot read propert|is not a function|is not defined|'
    r'ECONNREFUSED|ENOTFOUND|ETIMEDOUT|'
    r'TypeError|ReferenceError|SyntaxError|RangeError|'
    r'Internal Server Error|MongoServerError|BSON',
    caseSensitive: false,
  );

  static const _friendlyServerError =
      'Something went wrong on our end. Please try again later.';

  /// Returns `true` when the message looks like a raw server-side crash rather
  /// than a user-facing validation error.
  static bool _isServerCrash(String msg) => _serverCrashPattern.hasMatch(msg);

  String extractError(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        if (kDebugMode) {
          return 'Server did not respond in time. Check VITE_API_URL / API_BASE_URL / API_HOST ($baseUrl) and that the backend is running.';
        }
        return 'Server is waking up. Please wait a moment and try again.';
      }
      if (e.type == DioExceptionType.connectionError) {
        if (kDebugMode) {
          return 'Cannot reach server at $baseUrl. Set --dart-define=VITE_API_URL=... (or API_BASE_URL, or API_HOST for LAN dev).';
        }
        return 'Cannot reach the server. Check your internet connection and try again.';
      }
      if (e.response?.statusCode == 401) {
        final path = e.requestOptions.path;
        if (path.endsWith('/login') || path.endsWith('/register')) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            return data['message'].toString();
          }
          return 'Invalid credentials.';
        }
        return 'Session expired. Please log in again.';
      }
      if (e.response?.statusCode == 403) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          final msg = data['message'].toString();
          return _isServerCrash(msg) ? _friendlyServerError : msg;
        }
        return 'Access denied. Please try again or contact support.';
      }
      if (e.response?.statusCode == 429) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          return data['message'].toString();
        }
        return 'Too many attempts right now. Please wait a minute and try again.';
      }
      // 500-class errors are always server bugs — give a friendly message.
      final statusCode = e.response?.statusCode ?? 0;
      if (statusCode >= 500) {
        assert(() { debugPrint('API $statusCode: ${e.response?.data}'); return true; }());
        return _friendlyServerError;
      }
      final data = e.response?.data;
      if (data is Map) {
        if (data['errors'] is List) {
          final joined = (data['errors'] as List).join(' · ');
          return _isServerCrash(joined) ? _friendlyServerError : joined;
        }
        final msg = data['message']?.toString();
        if (msg != null) {
          return _isServerCrash(msg) ? _friendlyServerError : msg;
        }
        return e.message ?? 'Request failed';
      }
      final raw = e.message ?? e.toString();
      return _isServerCrash(raw) ? _friendlyServerError : raw;
    }
    final raw = e.toString();
    return _isServerCrash(raw) ? _friendlyServerError : raw;
  }
}
