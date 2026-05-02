import 'dart:io';
import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import '../services/verification_service.dart';
import '../theme/app_theme.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _service = VerificationService.instance;
  String _status = 'none'; // none, pending, verified, rejected
  String? _method;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final data = await _service.getStatus();
      if (mounted) {
        setState(() {
          _status = data['verificationStatus'] ?? 'none';
          _method = data['verificationMethod'];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifySchoolEmail() async {
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });
    try {
      final result = await _service.requestSchoolEmail();
      if (mounted) {
        setState(() {
          _submitting = false;
          _status = result['status'] ?? _status;
          _success = result['message'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = _service.extractError(e);
        });
      }
    }
  }

  Future<void> _uploadId() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920);
    if (xfile == null) return;
    final file = File(xfile.path);

    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });
    try {
      final result = await _service.uploadId(file);
      if (mounted) {
        setState(() {
          _submitting = false;
          _status = result['status'] ?? 'pending';
          _success = result['message'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = _service.extractError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Verification')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status banner
                  _StatusBanner(status: _status, method: _method),
                  const SizedBox(height: 32),

                  if (_status == 'verified') ...[
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.verified_rounded,
                              size: 80, color: Color(0xFF16A34A)),
                          const SizedBox(height: 16),
                          const Text('Your profile is verified!',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  color: AppColors.navy)),
                        ],
                      ),
                    ),
                  ] else if (_status == 'pending') ...[
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.hourglass_top_rounded,
                              size: 80, color: Color(0xFFD97706)),
                          const SizedBox(height: 16),
                          const Text('Verification pending',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  color: AppColors.navy)),
                          const SizedBox(height: 8),
                          const Text('An admin will review your submission soon.',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 14)),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text('Get Verified',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            color: AppColors.navy)),
                    const SizedBox(height: 8),
                    const Text('Verified profiles build trust and stand out to employers.',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 14)),
                    const SizedBox(height: 24),

                    // Option 1: School email
                    _VerificationOption(
                      icon: Icons.school_rounded,
                      title: 'School Email',
                      description:
                          'Instantly verify if your email is from an accredited school (e.g., .edu, .edu.ph)',
                      onTap: _submitting ? null : _verifySchoolEmail,
                      loading: _submitting,
                    ),
                    const SizedBox(height: 16),

                    // Option 2: ID upload
                    _VerificationOption(
                      icon: Icons.badge_rounded,
                      title: 'Upload Student ID',
                      description:
                          'Upload a photo of your student ID or government ID for admin review',
                      onTap: _submitting ? null : _uploadId,
                      loading: _submitting,
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: Color(0xFFB91C1C), fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: Color(0xFF16A34A), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_success!,
                                style: const TextStyle(
                                    color: Color(0xFF166534), fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final String? method;
  const _StatusBanner({required this.status, this.method});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    IconData icon;
    String label;
    switch (status) {
      case 'verified':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        icon = Icons.verified_rounded;
        label = 'Verified${method != null ? ' via ${method!.replaceAll('_', ' ')}' : ''}';
        break;
      case 'pending':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        icon = Icons.hourglass_top_rounded;
        label = 'Pending review';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        icon = Icons.cancel_rounded;
        label = 'Verification rejected — try again';
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        icon = Icons.shield_outlined;
        label = 'Not verified';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 24),
          const SizedBox(width: 12),
          Text(label,
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: fg)),
        ],
      ),
    );
  }
}

class _VerificationOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool loading;

  const _VerificationOption({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadowLight,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.navy, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.navy)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
