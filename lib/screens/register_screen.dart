import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  /// Optional Google ID token passed from login screen when a new user needs role selection.
  final String? googleToken;
  const RegisterScreen({super.key, this.googleToken});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _uniCtrl = TextEditingController();
  String _role = 'student';
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _agreedToTerms = false;
  String? _error;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  static const _googleClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '');

  @override
  void initState() {
    super.initState();
    // If redirected from login with a google token that needs role selection,
    // auto-trigger Google sign-up once the user picks a role.
    if (widget.googleToken != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completeGoogleSignUp(widget.googleToken!);
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _uniCtrl.dispose();
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

  // ── Google Sign-Up ──────────────────────────────────────────────────────
  Future<void> _handleGoogleSignUp() async {
    if (_googleLoading) return;
    setState(() { _googleLoading = true; _error = null; });
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: _googleClientId.isNotEmpty ? _googleClientId : null,
        scopes: ['email', 'profile'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        if (mounted) setState(() => _googleLoading = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        if (mounted) setState(() { _googleLoading = false; _error = 'Could not obtain Google credentials.'; });
        return;
      }
      await _completeGoogleSignUp(idToken);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = ref.read(authServiceProvider).extractError(e); });
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _completeGoogleSignUp(String idToken) async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      final needsRole = await ref.read(authProvider.notifier).googleLogin(idToken, role: _role);
      if (!mounted) return;
      if (needsRole) {
        setState(() { _error = 'Please select a role and try again.'; _googleLoading = false; });
        return;
      }
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = ref.read(authServiceProvider).extractError(e); _googleLoading = false; });
    }
  }

  String? _validatePassword(String pass) {
    if (pass.length < 12) return 'Password must be at least 12 characters';
    if (!pass.contains(RegExp(r'[a-z]'))) return 'Must contain a lowercase letter';
    if (!pass.contains(RegExp(r'[A-Z]'))) return 'Must contain an uppercase letter';
    if (!pass.contains(RegExp(r'\d'))) return 'Must contain a number';
    if (!pass.contains(RegExp(r'[@$!%*?&]'))) return 'Must contain a special char (@\$!%*?&)';
    return null;
  }

  void _setAgreedToTerms(bool value) {
    setState(() {
      _agreedToTerms = value;
      if (value) _error = null;
    });
  }

  Future<void> _submit() async {
    if (_remainingSeconds > 0) {
      return;
    }
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      final secs = _lockedUntil!.difference(DateTime.now()).inSeconds;
      _startLockoutTimer(secs);
      return;
    }

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all required fields.');
      return;
    }
    final passErr = _validatePassword(pass);
    if (passErr != null) {
      setState(() => _error = passErr);
      return;
    }
    if (!_agreedToTerms) {
      setState(() => _error = 'Please agree to the Terms of Service and Privacy Policy.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).register(
            name: name,
            email: email,
            password: pass,
            role: _role,
            university: _role == 'student' ? _uniCtrl.text.trim() : null,
            agreedToTerms: _agreedToTerms,
          );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        final delaySecs = _failedAttempts >= 10 ? 3600 : 900; // 60 mins or 15 mins
        _lockedUntil = DateTime.now().add(Duration(seconds: delaySecs));
        _startLockoutTimer(delaySecs);
        setState(() {
          _error = 'Too many failed attempts. Please wait.';
          _loading = false;
        });
      } else {
        setState(() {
          _error = ref.read(authServiceProvider).extractError(e);
          _loading = false;
        });
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
              const SizedBox(height: 24),
              // Header
              const Text('CREATE ACCOUNT',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: AppColors.textMuted)),
              const SizedBox(height: 8),
              const Text('Join HeartConnect',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              const SizedBox(height: 32),

              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: 18),
              ],

              // Full Name
              _Field('Full Name', _nameCtrl, hint: 'Jane Doe'),
              const SizedBox(height: 16),
              _Field('Email', _emailCtrl,
                  hint: 'jane@example.com',
                  type: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _Field('University', _uniCtrl, hint: 'State University'),
              const SizedBox(height: 16),
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
                decoration: InputDecoration(
                  hintText: '••••••••',
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
              const SizedBox(height: 20),

              // Select Role
              const Text('Select Role',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textBody)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _RoleToggle(
                  icon: Icons.school_outlined,
                  label: 'Student',
                  selected: _role == 'student',
                  onTap: () => setState(() => _role = 'student'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _RoleToggle(
                  icon: Icons.business_center_outlined,
                  label: 'Client',
                  selected: _role == 'client',
                  onTap: () => setState(() => _role = 'client'),
                )),
              ]),
              const SizedBox(height: 20),

              // Terms
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _agreedToTerms,
                      onChanged: (v) => _setAgreedToTerms(v ?? false),
                      activeColor: AppColors.navy,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _setAgreedToTerms(!_agreedToTerms),
                      child: const Text(
                        'I agree to the Terms of Service.',
                        style: TextStyle(fontSize: 13, color: AppColors.textBody),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Create Account button
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
                        : 'Create Account'),
              ),

              // OR divider + Google
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('or',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ),
                  Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _googleLoading ? null : _handleGoogleSignUp,
                icon: _googleLoading
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                    : Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        height: 20, width: 20,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.g_mobiledata, size: 22, color: AppColors.navy),
                      ),
                label: Text(
                  _googleLoading ? 'Creating account…' : 'Sign up with Google',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textBody),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),

              const SizedBox(height: 32),
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/login'),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      children: [
                        TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Sign In.',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final TextInputType? type;
  const _Field(this.label, this.ctrl, {this.hint, this.type});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: AppColors.textBody)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: type,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class _RoleToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RoleToggle(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          border: Border.all(
              color: selected ? AppColors.navy : AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? Colors.white : AppColors.textBody),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : AppColors.textBody)),
          ],
        ),
      ),
    );
  }
}
