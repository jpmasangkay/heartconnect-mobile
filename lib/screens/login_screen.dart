import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/two_factor_verify_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  /// Google Client ID — passed at build-time via --dart-define=GOOGLE_CLIENT_ID=...
  static const _googleClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '');

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startLockoutTimer(int seconds) {
    setState(() => _remainingSeconds = seconds);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        setState(() {
          _remainingSeconds = 0;
          _lockedUntil = null;
          _error = null;
        });
        timer.cancel();
      }
    });
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    if (_googleLoading) return;
    setState(() {
      _googleLoading = true;
      _error = null;
    });

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: _googleClientId.isNotEmpty ? _googleClientId : null,
        scopes: ['email', 'profile'],
      );

      // Start native Google sign-in flow
      final account = await googleSignIn.signIn();
      if (account == null) {
        // User cancelled
        if (mounted) setState(() => _googleLoading = false);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        if (mounted) {
          setState(() {
            _googleLoading = false;
            _error = 'Could not obtain Google credentials. Please try again.';
          });
        }
        return;
      }

      // Send ID token to backend
      final needsRole =
          await ref.read(authProvider.notifier).googleLogin(idToken);
      if (!mounted) return;

      if (needsRole) {
        // New user — redirect to register screen with the google token
        context.go('/register', extra: {'googleToken': idToken});
        return;
      }

      final authState = ref.read(authProvider);
      context.go(authState.user?.role == 'admin' ? '/admin' : '/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ref.read(authServiceProvider).extractError(e);
      });
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _submit() async {
    // Client-side rate limiting after repeated failures
    if (_remainingSeconds > 0) {
      return;
    }
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      final secs = _lockedUntil!.difference(DateTime.now()).inSeconds;
      _startLockoutTimer(secs);
      return;
    }

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final isValidEmail =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (email.isEmpty || pass.isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (!isValidEmail) {
      if (!mounted) return;
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(email, pass);
      if (!mounted) return;

      final authState = ref.read(authProvider);
      if (authState.requires2FA) {
        setState(() => _loading = false);
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => TwoFactorVerifyDialog(
            method: authState.twoFactorMethod ?? 'email',
            tempToken: authState.tempToken ?? '',
          ),
        );
        if (result == true && mounted) {
          final authAfter2FA = ref.read(authProvider);
          context.go(authAfter2FA.user?.role == 'admin' ? '/admin' : '/dashboard');
        }
        return;
      }

      final authAfterLogin = ref.read(authProvider);
      context.go(authAfterLogin.user?.role == 'admin' ? '/admin' : '/dashboard');
    } catch (e) {
      if (!mounted) return;
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        final delaySecs = _failedAttempts >= 10 ? 3600 : 900; // 60 mins or 15 mins
        _lockedUntil = DateTime.now().add(Duration(seconds: delaySecs));
        _startLockoutTimer(delaySecs);
        setState(() {
          _error = 'Too many failed attempts. Please wait.';
        });
      } else {
        setState(() {
          _error = ref.read(authServiceProvider).extractError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              // Header
              const Center(
                child: Text('WELCOME BACK',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppColors.textMuted)),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('HeartConnect',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
              ),
              const SizedBox(height: 40),

              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: 18),
              ],

              // Email
              const Text('Email',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textBody)),
              const SizedBox(height: 6),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    hintText: 'you@university.edu'),
              ),

              const SizedBox(height: 18),

              // Password
              const Text('Password',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textBody)),
              const SizedBox(height: 6),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.textMuted),
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => context.push('/forgot-password'),
                  child: const Text('Forgot Password?',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 24),

              // Sign In button
              ElevatedButton(
                onPressed: (_loading || _remainingSeconds > 0) ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_remainingSeconds > 0
                        ? 'Try again in ${_remainingSeconds >= 60 ? '${_remainingSeconds ~/ 60}m ${_remainingSeconds % 60}s' : '${_remainingSeconds}s'}'
                        : 'Sign In'),
              ),

              // ── OR divider + Google Sign-In ────────────────────
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('or',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted)),
                  ),
                  Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _googleLoading ? null : _handleGoogleSignIn,
                icon: _googleLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.navy))
                    : Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        height: 20,
                        width: 20,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.g_mobiledata, size: 22, color: AppColors.navy),
                      ),
                label: Text(
                  _googleLoading ? 'Signing in…' : 'Sign in with Google',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textBody),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),

              const SizedBox(height: 32),
              // Bottom link
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/register'),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      children: [
                        TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Register',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
