import 'package:dio/dio.dart';
import '../models/user.dart';
import 'api_service.dart';

/// Registers and logs in via JSON body; persists Bearer JWT from the response.
class AuthService extends ApiService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Returns either a normal login result OR a 2FA challenge.
  Future<({String? token, User? user, bool requires2FA, String? tempToken, String? twoFactorMethod})> login(
      String email, String password) async {
    final res = await dio.post('/auth/login', data: {
      'email': email,
      'password': password,
      'platform': ApiService.platform,
    });
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

  Future<({String token, User user})> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? university,
  }) async {
    final res = await dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      'platform': ApiService.platform,
      if (university != null && university.isNotEmpty) 'university': university,
    });
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
}
