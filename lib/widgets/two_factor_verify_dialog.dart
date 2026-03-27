import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Dialog shown during login when 2FA is required.
class TwoFactorVerifyDialog extends ConsumerStatefulWidget {
  final String method; // 'totp' or 'email'
  final String tempToken;

  const TwoFactorVerifyDialog({
    super.key,
    required this.method,
    required this.tempToken,
  });

  @override
  ConsumerState<TwoFactorVerifyDialog> createState() => _TwoFactorVerifyDialogState();
}

class _TwoFactorVerifyDialogState extends ConsumerState<TwoFactorVerifyDialog> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length < 6) {
      setState(() => _error = 'Please enter the 6-digit code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).verify2FA(code);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = ref.read(authProvider).error ?? 'Invalid code';
        });
      }
    }
  }

  Future<void> _resendEmailCode() async {
    try {
      final service = ref.read(twoFactorServiceProvider);
      await service.sendEmailCode(widget.tempToken);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code sent to your email')),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = widget.method == 'email';

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEmail ? Icons.email_rounded : Icons.security_rounded,
                color: AppColors.navy,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text('Two-Factor Verification',
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.navy)),
            const SizedBox(height: 8),
            Text(
              isEmail
                  ? 'Enter the 6-digit code sent to your email'
                  : 'Enter the code from your authenticator app',
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
              ),
              onSubmitted: (_) => _verify(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.red)),
            ],
            if (isEmail) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _resendEmailCode,
                child: Text('Resend code',
                    style: GoogleFonts.inter(
                        color: AppColors.accent, fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () {
                            ref.read(authProvider.notifier).clear2FA();
                            Navigator.of(context).pop(false);
                          },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Verify'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
