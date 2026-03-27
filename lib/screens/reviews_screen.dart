import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../services/review_service.dart';
import '../models/review.dart';
import '../theme/app_theme.dart';
import '../widgets/review_dialog.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  final _service = ReviewService();

  bool _loading = true;
  List<Review> _reviews = [];
  double _avg = 0;
  List<PendingReview> _pending = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = ref.read(authProvider).user;
    if (me == null) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getUserReviews(me.id),
        _service.getPendingReviews(),
      ]);
      final userReviews = results[0] as ({List<Review> data, double avgRating, int total, int pages});
      final pending = results[1] as List<PendingReview>;
      if (!mounted) return;
      setState(() {
        _reviews = userReviews.data;
        _avg = userReviews.avgRating;
        _pending = pending;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _leaveReview(PendingReview p) async {
    final job = p.job;
    final reviewee = p.reviewee;
    if (job == null || reviewee == null) return;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => ReviewDialog(job: job, reviewee: reviewee),
    );
    if (submitted == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Reviews'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(avg: _avg, count: _reviews.length, role: me?.role),
                  const SizedBox(height: 12),
                  if (_pending.isNotEmpty) ...[
                    _Section(
                      title: 'Pending reviews',
                      child: Column(
                        children: _pending.map((p) {
                          final job = p.job;
                          final u = p.reviewee;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.rate_review_rounded, color: AppColors.navy),
                            title: Text(job?.title ?? 'Job'),
                            subtitle: Text('Review ${u?.name ?? 'user'}'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _leaveReview(p),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _Section(
                    title: 'All reviews',
                    child: _reviews.isEmpty
                        ? const Text(
                            'No reviews yet.',
                            style: TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic),
                          )
                        : Column(
                            children: _reviews.map((r) => _ReviewTile(r)).toList(),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double avg;
  final int count;
  final String? role;
  const _SummaryCard({required this.avg, required this.count, required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.creamDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${avg.toStringAsFixed(1)} / 5.0',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count review${count == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (role != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.creamDark,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                role!.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textBody)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review r;
  const _ReviewTile(this.r);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 14,
                  color: i < r.rating ? const Color(0xFFF59E0B) : AppColors.border,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.reviewer?.name ?? 'Anonymous',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textBody),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (r.comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.comment, style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

