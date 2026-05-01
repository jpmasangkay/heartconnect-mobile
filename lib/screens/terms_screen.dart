import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Terms of Service',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 24, color: AppColors.navy)),
            const SizedBox(height: 8),
            const Text('Last updated: March 2026',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 24),
            _section('1. Acceptance of Terms',
                'By accessing or using HeartConnect, you agree to be bound by these Terms of Service. If you do not agree, you may not use the platform.'),
            _section('2. User Accounts',
                'You must provide accurate information when creating an account. You are responsible for maintaining the security of your account and password. You must be at least 16 years old to use this service.'),
            _section('3. User Conduct',
                'You agree not to: post false or misleading information, harass other users, engage in fraudulent activity, violate any applicable laws, or attempt to compromise the security of the platform.'),
            _section('4. Job Postings',
                'Clients are responsible for accurately describing jobs and compensating freelancers as agreed. Freelancers are responsible for delivering work as described in their applications.'),
            _section('5. Content',
                'You retain ownership of content you post but grant HeartConnect a license to display and distribute it on the platform. You must not post content that infringes on others\' rights.'),
            _section('6. Privacy',
                'Your use of HeartConnect is also governed by our Privacy Policy. Please review it to understand how we collect and use your information.'),
            _section('7. Disputes',
                'HeartConnect provides the platform for connecting users but is not a party to agreements between clients and freelancers. Disputes should be resolved between the parties involved.'),
            _section('8. Termination',
                'We reserve the right to suspend or terminate accounts that violate these terms or for any reason at our discretion.'),
            _section('9. Changes',
                'We may update these terms from time to time. Continued use of the platform constitutes acceptance of the updated terms.'),
            _section('10. Contact',
                'For questions about these terms, contact us at support@heartconnect.app.'),
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
