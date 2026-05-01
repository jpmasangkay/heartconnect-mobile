import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/two_factor_service.dart';
import '../theme/app_theme.dart';

class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  final _service = TwoFactorService.instance;
  bool _loading = false;
  String? _error;
  String? _success;

  // Setup state
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }



  Future<void> _setupEmail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.setup('email');
      if (mounted) {
        setState(() {
          _loading = false;
          _success = '2FA via email enabled successfully!';
        });
        // Refresh user data
        final user = ref.read(authProvider).user;
        if (user != null) {
          ref.read(authProvider.notifier).updateUser(
            user.copyWith(twoFactorEnabled: true, twoFactorMethod: 'email'),
          );
        }
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



  Future<void> _disable() async {
    if (_passwordController.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.disable(
        _passwordController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _success = '2FA disabled.';
        });
        _passwordController.clear();
        final user = ref.read(authProvider).user;
        if (user != null) {
          ref.read(authProvider.notifier).updateUser(
            user.copyWith(twoFactorEnabled: false),
          );
        }
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
    final authState = ref.watch(authProvider);
    final is2FA = authState.user?.twoFactorEnabled ?? false;
    final method = authState.user?.twoFactorMethod;

    return Scaffold(
      appBar: AppBar(title: const Text('Two-Factor Authentication')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: is2FA ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    is2FA ? Icons.shield_rounded : Icons.shield_outlined,
                    color: is2FA ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(is2FA ? '2FA Enabled' : '2FA Not Enabled',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        if (is2FA && method != null)
                          const Text('Method: Email',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_success != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_success!,
                        style: const TextStyle(color: Color(0xFF166534), fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Disable flow
            if (is2FA) ...[
              const Text('Disable 2FA',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.navy)),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Current password'),
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _disable,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Disable 2FA'),
              ),
            ]
            // Enable options
            else ...[
              const Text('Choose a method',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.navy)),
              const SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppColors.cardShadowLight,
                ),
                child: ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.email_rounded, color: AppColors.navy),
                  ),
                  title: const Text('Email',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Receive a code via email on each login',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _loading ? null : _setupEmail,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
