import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
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
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text('Skip',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
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
            // Indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _pages.length,
                effect: ExpandingDotsEffect(
                  activeDotColor: AppColors.navy,
                  dotColor: AppColors.border,
                  dotHeight: 8,
                  dotWidth: 8,
                  expansionFactor: 3,
                ),
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
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Icon(icon, size: 56, color: color),
          ),
          const SizedBox(height: 40),
          Text(title,
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800, fontSize: 28, color: AppColors.navy),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(subtitle,
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 15, height: 1.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
