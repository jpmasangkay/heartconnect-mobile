import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _service = AuthService.instance;
  bool _loading = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      final msg = await _service.forgotPassword(email);
      if (mounted) {
        setState(() {
          _loading = false;
          _message = msg;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _service.extractError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text('ACCOUNT RECOVERY',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: AppColors.textMuted)),
            const SizedBox(height: 8),
            const Text('Forgot Password?',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
            const SizedBox(height: 12),
            const Text(
                "Enter your university email and we'll send you a reset link.",
                style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5)),
            const SizedBox(height: 32),

            // Email Address
            const Text('Email Address',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textBody)),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: 'you@university.edu',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send Reset Link'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_message!,
                          style: const TextStyle(
                              color: AppColors.successDark, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 32),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    children: [
                      TextSpan(text: 'Remember your password? '),
                      TextSpan(
                        text: 'Sign In',
                        style: TextStyle(
                            color: AppColors.navy,
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
    );
  }
}
