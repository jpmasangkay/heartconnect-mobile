import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _pages = const [
    _OnboardingPage(
      icon: Icons.work_rounded,
      title: 'Find or Post Jobs',
      subtitle: 'Browse job listings from fellow students or post your own projects for freelancers to tackle.',
      color: Color(0xFF2563EB),
    ),
    _OnboardingPage(
      icon: Icons.chat_bubble_rounded,
      title: 'Chat in Real-Time',
      subtitle: 'Message applicants or employers directly with real-time messaging, file sharing, and read receipts.',
      color: Color(0xFF16A34A),
    ),
    _OnboardingPage(
      icon: Icons.star_rounded,
      title: 'Build Your Reputation',
      subtitle: 'Get verified, collect reviews, and build a trusted profile that stands out to employers.',
      color: Color(0xFFF59E0B),
    ),
    _OnboardingPage(
      icon: Icons.security_rounded,
      title: 'Stay Safe',
      subtitle: 'Two-factor authentication, verified profiles, and reporting tools keep the community safe and trusted.',
      color: Color(0xFF7C3AED),
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await ref.read(authProvider.notifier).markOnboardingComplete();
    if (mounted) context.go('/dashboard');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: back arrow + Skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                    onPressed: () {
                      if (_currentPage > 0) {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                            fontSize: 15)),
                  ),
                ],
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _pages[i],
              ),
            ),
            // Red dot indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _currentPage
                          ? AppColors.accent
                          : AppColors.border,
                    ),
                  );
                }),
              ),
            ),
            // Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: ElevatedButton(
                onPressed: _next,
                child: Text(isLast ? 'Get Started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 56, color: AppColors.navy),
          ),
          const SizedBox(height: 40),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 24, color: AppColors.navy),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(subtitle,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 15, height: 1.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
