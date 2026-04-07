import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
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
  bool _agreedToTerms = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _uniCtrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String pass) {
    if (pass.length < 12) return 'Password must be at least 12 characters';
    if (!pass.contains(RegExp(r'[a-z]'))) return 'Must contain a lowercase letter';
    if (!pass.contains(RegExp(r'[A-Z]'))) return 'Must contain an uppercase letter';
    if (!pass.contains(RegExp(r'\d'))) return 'Must contain a number';
    if (!pass.contains(RegExp(r'[@$!%*?&]'))) return 'Must contain a special char (@\$!%*?&)';
    return null;
  }

  Future<void> _submit() async {
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
          );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ref.read(authServiceProvider).extractError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.go('/'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.creamDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.arrow_back_ios_rounded, size: 12, color: AppColors.textMuted),
                    SizedBox(width: 4),
                    Text('Back', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
              const SizedBox(height: 44),
              const Text('JOIN HEARTCONNECT',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.textMuted)),
              const SizedBox(height: 10),
              const Text('Create your account',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy)),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Already have an account? ',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: const Text('Sign in',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Role picker
                    const Text('I want to',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.textBody)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _RoleCard(
                        icon: Icons.school,
                        title: 'Find freelance work',
                        sub: "I'm a student",
                        selected: _role == 'student',
                        onTap: () => setState(() => _role = 'student'),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _RoleCard(
                        icon: Icons.work,
                        title: 'Hire freelancers',
                        sub: "I'm a client",
                        selected: _role == 'client',
                        onTap: () => setState(() => _role = 'client'),
                      )),
                    ]),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      ErrorBanner(_error!),
                      const SizedBox(height: 18),
                    ],
                    _Field('Full name', _nameCtrl, hint: 'Maria Santos'),
                    const SizedBox(height: 16),
                    _Field('Email address', _emailCtrl,
                        hint: 'you@university.edu',
                        type: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    if (_role == 'student') ...[
                      _Field('University / School', _uniCtrl,
                          hint: 'University of the Philippines'),
                      const SizedBox(height: 16),
                    ],
                    const Text('Password',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.textBody)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: 'Min. 12 chars, upper, lower, number, special',
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
                    const Text(
                        'Must be 12+ chars with uppercase, lowercase, number, and @\$!%*?&',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24, height: 24,
                          child: Checkbox(
                            value: _agreedToTerms,
                            onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                            activeColor: AppColors.navy,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            children: [
                              const Text('I agree to the ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                              GestureDetector(
                                onTap: () => context.push('/terms'),
                                child: const Text('Terms of Service',
                                    style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
                              ),
                              const Text(' and ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                              GestureDetector(
                                onTap: () => context.push('/privacy'),
                                child: const Text('Privacy Policy',
                                    style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Create account'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
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

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard(
      {required this.icon,
      required this.title,
      required this.sub,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.cream,
          border: Border.all(
              color: selected ? AppColors.navy : AppColors.border.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected ? AppColors.cardShadowLight : [],
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22,
                color: selected ? Colors.white : AppColors.navy),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textBody)),
            const SizedBox(height: 2),
            Text(sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    color: selected
                        ? Colors.white70
                        : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
