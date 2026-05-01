import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Privacy Policy',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 24, color: AppColors.navy)),
            const SizedBox(height: 8),
            const Text('Last updated: March 2026',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 24),
            _section('1. Information We Collect',
                'We collect information you provide directly: name, email, university, profile data, and any content you post. We also collect usage data such as login times and feature usage.'),
            _section('2. How We Use Information',
                'We use your information to: provide and improve the platform, match students with job opportunities, send notifications, maintain security, and communicate with you about your account.'),
            _section('3. Information Sharing',
                'We do not sell your personal information. We share information only with: other users as needed to facilitate job connections, service providers who help operate the platform, and when required by law.'),
            _section('4. Data Security',
                'We implement security measures including encrypted passwords, JWT authentication, two-factor authentication, and rate limiting to protect your data.'),
            _section('5. Data Retention',
                'We retain your data while your account is active. You may request deletion of your account and associated data by contacting us.'),
            _section('6. Cookies and Tokens',
                'We use JWT tokens stored securely on your device for authentication. We do not use tracking cookies.'),
            _section('7. Your Rights',
                'You have the right to: access your personal information, correct inaccurate information, request deletion of your data, and withdraw consent for data processing.'),
            _section('8. Children\'s Privacy',
                'HeartConnect is not intended for users under 16 years of age. We do not knowingly collect information from children.'),
            _section('9. Changes to This Policy',
                'We may update this policy periodically. We will notify you of significant changes through the app or via email.'),
            _section('10. Contact',
                'For privacy-related questions, contact us at privacy@heartconnect.app.'),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.navy)),
          const SizedBox(height: 8),
          Text(content,
              style: const TextStyle(
                  color: AppColors.textBody, fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}
