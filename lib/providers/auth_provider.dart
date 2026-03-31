import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/two_factor_service.dart';

final authServiceProvider = Provider((ref) => AuthService.instance);
final twoFactorServiceProvider = Provider((ref) => TwoFactorService.instance);

class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;

  // 2FA flow
  final bool requires2FA;
  final String? tempToken;
  final String? twoFactorMethod;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.requires2FA = false,
    this.tempToken,
    this.twoFactorMethod,
  });

  bool get isAuthenticated => user != null && token != null;
  bool get needsOnboarding => isAuthenticated && user?.hasCompletedOnboarding == false;

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool? requires2FA,
    String? tempToken,
    String? twoFactorMethod,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: clearUser ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      error: error,
      requires2FA: requires2FA ?? this.requires2FA,
      tempToken: clearUser ? null : (tempToken ?? this.tempToken),
      twoFactorMethod: clearUser ? null : (twoFactorMethod ?? this.twoFactorMethod),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _init();
    return const AuthState(isLoading: true);
  }

  AuthService get _service => ref.read(authServiceProvider);
  TwoFactorService get _twoFactorService => ref.read(twoFactorServiceProvider);

  Future<void> _init() async {
    ApiService.onAuthExpired = _handleAuthExpired;
    try {
      final user = await _service.getCurrentUser();
      final token = await ApiService.getToken();
      if (user != null && token != null) {
        state = AuthState(user: user, token: token);
      } else {
        await ApiService.clearToken();
        state = const AuthState();
      }
    } catch (_) {
      await ApiService.clearToken();
      state = const AuthState();
    }
  }

  void _handleAuthExpired() {
    if (state.isAuthenticated) {
      state = const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null, requires2FA: false);
    try {
      final result = await _service.login(email, password);

      if (result.requires2FA) {
        state = AuthState(
          requires2FA: true,
          tempToken: result.tempToken,
          twoFactorMethod: result.twoFactorMethod,
        );
        return;
      }

      state = AuthState(user: result.user, token: result.token);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _service.extractError(e),
      );
      rethrow;
    }
  }

  Future<void> verify2FA(String code) async {
    if (state.tempToken == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _twoFactorService.verify(state.tempToken!, code);
      final token = data['token'] as String;
      await ApiService.setToken(token);
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = AuthState(user: user, token: token);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _service.extractError(e),
      );
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? university,
    bool agreedToTerms = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.register(
        name: name,
        email: email,
        password: password,
        role: role,
        university: university,
      );
      state = AuthState(user: result.user, token: result.token);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _service.extractError(e),
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    await _service.logout();
    state = const AuthState();
  }

  void updateUser(User updatedUser) {
    state = state.copyWith(user: updatedUser);
  }

  Future<void> markOnboardingComplete() async {
    try {
      await _service.markOnboardingComplete();
      if (state.user != null) {
        state = state.copyWith(
          user: state.user!.copyWith(hasCompletedOnboarding: true),
        );
      }
    } catch (_) {}
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void clear2FA() {
    state = state.copyWith(requires2FA: false, tempToken: null, twoFactorMethod: null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() => AuthNotifier());
