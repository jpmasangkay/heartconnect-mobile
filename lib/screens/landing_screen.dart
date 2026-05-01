import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
                ),
              ),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    top: -60,
                    left: -80,
                    child: _Orb(size: 320, color: AppColors.navy.withValues(alpha: 0.05)),
                  ),
                  Positioned(
                    top: 80,
                    right: -60,
                    child: _Orb(size: 240, color: AppColors.accent.withValues(alpha: 0.05)),
                  ),
                  Positioned(
                    bottom: 100,
                    left: 60,
                    child: _Orb(size: 180, color: AppColors.navy.withValues(alpha: 0.03)),
                  ),
                  // Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints:
                                  BoxConstraints(minHeight: constraints.maxHeight),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 24),
                                  // Nav row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(children: [
                                        Image.asset(
                                          'assets/logo.png',
                                          height: 24,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'HeartConnect',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: AppColors.navy,
                                          ),
                                        ),
                                      ]),
                                      OutlinedButton(
                                        onPressed: () => context.go('/login'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Sign in',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 48),
                                  // Label
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.navy
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: const Text(
                                      'For Cordians, by Cordians',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'Connecting\nSkills to\nEvery Need.',
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'A dedicated space for Cordians to find work, gain experience, and help each other.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textMuted,
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 36),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              context.go('/register'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.navy,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                          ),
                                          child:
                                              const Text('Be a Freelancer'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              context.go('/register'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                          ),
                                          child: const Text('Hire Talent'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 40),
                                  // Stats row
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: AppColors.cardShadow,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: const [
                                        _StatItem('500+', 'Students'),
                                        _Divider(),
                                        _StatItem('120+', 'Open Gigs'),
                                        _Divider(),
                                        _StatItem('40+', 'Categories'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Categories ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('WHAT WE OFFER',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  const Text('Browse by Category',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _categories.map((c) => _CategoryCard(c)).toList(),
              ),
            ),
          ),

          // ── CTA ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Start building your portfolio today.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/register'),
                    style: ButtonStyle(
                      backgroundColor: const WidgetStatePropertyAll(Color(0xFFFFFFFF)),
                      foregroundColor: const WidgetStatePropertyAll(AppColors.navy),
                      side: const WidgetStatePropertyAll(BorderSide.none),
                      overlayColor: WidgetStatePropertyAll(AppColors.navy.withValues(alpha: 0.08)),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      ),
                      elevation: const WidgetStatePropertyAll(0),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

const _categories = [
  (
    title: 'Web Development',
    desc: 'Build landing pages, web apps, and everything in between.',
    icon: Icons.code,
    color: Color(0xFF1A1D2B),
  ),
  (
    title: 'Graphic Design',
    desc: 'Brand identity, logos, social content — make it iconic.',
    icon: Icons.palette,
    color: Color(0xFF6B21A8),
  ),
  (
    title: 'Cybersecurity',
    desc: 'Pen testing, compliance audits, and threat analysis.',
    icon: Icons.shield,
    color: Color(0xFF0D47A1),
  ),
  (
    title: 'Marketing',
    desc: 'Drive results with strategy and student-led execution.',
    icon: Icons.campaign,
    color: Color(0xFFE53935),
  ),
  (
    title: 'Data Science',
    desc: 'Analytics, ML models, dashboards and data pipelines.',
    icon: Icons.bar_chart,
    color: Color(0xFF1565C0),
  ),
];

class _CategoryCard extends StatelessWidget {
  final ({String title, String desc, IconData icon, Color color}) cat;
  const _CategoryCard(this.cat);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadowLight,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/jobs'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat.icon, color: cat.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.navy)),
                    const SizedBox(height: 4),
                    Text(cat.desc,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.creamDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  const _StatItem(this.value, this.label);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.navy)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: AppColors.border.withValues(alpha: 0.1));
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
