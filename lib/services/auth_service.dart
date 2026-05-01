import 'package:dio/dio.dart';
import '../models/user.dart';
import 'api_service.dart';

/// Registers and logs in via JSON body; persists Bearer JWT from the response.
class AuthService extends ApiService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Returns either a normal login result OR a 2FA challenge.
  /// Automatically retries once on timeout (Render free-tier cold-start).
  Future<({String? token, User? user, bool requires2FA, String? tempToken, String? twoFactorMethod})> login(
      String email, String password) async {
    final body = {
      'email': email,
      'password': password,
      'platform': ApiService.platform,
    };

    Response res;
    try {
      res = await dio.post('/auth/login', data: body);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        // Server was likely cold-starting; retry once.
        res = await dio.post('/auth/login', data: body);
      } else {
        rethrow;
      }
    }

    final data = res.data as Map<String, dynamic>;

    // 2FA required
    if (data['requires2FA'] == true) {
      return (
        token: null,
        user: null,
        requires2FA: true,
        tempToken: data['tempToken'] as String?,
        twoFactorMethod: data['twoFactorMethod'] as String?,
      );
    }

    final token = data['token'] as String;
    await ApiService.setToken(token);
    return (
      token: token,
      user: User.fromJson(data['user'] as Map<String, dynamic>),
      requires2FA: false,
      tempToken: null,
      twoFactorMethod: null,
    );
  }
  /// Automatically retries once on timeout (Render free-tier cold-start).
  Future<({String token, User user})> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? university,
    required bool agreedToTerms,
  }) async {
    final body = {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      'platform': ApiService.platform,
      'agreedToTerms': agreedToTerms,
      if (university != null && university.isNotEmpty) 'university': university,
    };

    Response res;
    try {
      res = await dio.post('/auth/register', data: body);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        // Server was likely cold-starting; retry once.
        res = await dio.post('/auth/register', data: body);
      } else {
        rethrow;
      }
    }

    final data = res.data as Map<String, dynamic>;
    final token = data['token'] as String;
    await ApiService.setToken(token);
    return (token: token, user: User.fromJson(data['user'] as Map<String, dynamic>));
  }

  Future<User?> getCurrentUser() async {
    final token = await ApiService.getToken();
    if (token == null) return null;
    try {
      final res = await dio.get('/auth/me');
      final data = res.data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('_id')) return User.fromJson(data);
        if (data.containsKey('user')) return User.fromJson(data['user']);
      }
      return null;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        await ApiService.clearToken();
      }
      return null;
    }
  }

  Future<User> updateProfile(Map<String, dynamic> profileData) async {
    final res = await dio.put('/auth/profile', data: profileData);
    return User.fromJson(res.data as Map<String, dynamic>);
  }

  Future<User> getUser(String id) async {
    final res = await dio.get('/auth/users/$id');
    return User.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await dio.post('/auth/logout');
    } catch (_) {}
    await ApiService.clearToken();
  }

  Future<String> forgotPassword(String email) async {
    final res = await dio.post('/auth/forgot-password', data: {'email': email});
    return (res.data as Map<String, dynamic>)['message'] ?? 'Check your email';
  }

  Future<String> resetPassword(String token, String password) async {
    final res = await dio.post('/auth/reset-password', data: {
      'token': token,
      'password': password,
    });
    return (res.data as Map<String, dynamic>)['message'] ?? 'Password reset successful';
  }

  Future<void> markOnboardingComplete() async {
    await dio.patch('/auth/onboarding-complete');
  }

  /// Google OAuth login / registration.
  /// Returns token + user, or {needsRole: true} if the user is new and no role was provided.
  Future<({String? token, User? user, bool needsRole, bool isNewUser})> googleLogin(
      String idToken, String? role) async {
    final body = <String, dynamic>{
      'idToken': idToken,
      if (role != null) 'role': role,
    };

    final res = await dio.post('/auth/google', data: body);
    final data = res.data as Map<String, dynamic>;

    if (data['needsRole'] == true) {
      return (token: null, user: null, needsRole: true, isNewUser: false);
    }

    final token = data['token'] as String;
    await ApiService.setToken(token);
    return (
      token: token,
      user: User.fromJson(data['user'] as Map<String, dynamic>),
      needsRole: false,
      isNewUser: data['isNewUser'] == true,
    );
  }
}
