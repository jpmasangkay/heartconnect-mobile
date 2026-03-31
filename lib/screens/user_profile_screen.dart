import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/review_service.dart';
import '../services/block_service.dart';
import '../models/user.dart';
import '../models/review.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/report_dialog.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  User? _profile;
  bool _loading = true;
  bool _notFound = false;
  List<Review> _reviews = [];
  double _avgRating = 0;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await AuthService.instance.getUser(widget.userId);
      if (mounted) setState(() { _profile = user; _loading = false; });
      _loadReviews();
      _checkBlocked();
    } catch (_) {
      if (mounted) setState(() { _notFound = true; _loading = false; });
    }
  }

  Future<void> _loadReviews() async {
    try {
      final result = await ReviewService.instance.getUserReviews(widget.userId);
      if (mounted) {
        setState(() {
          _reviews = result.data;
          _avgRating = result.avgRating;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkBlocked() async {
    try {
      final blocked = await BlockService.instance.checkBlocked(widget.userId);
      if (mounted) setState(() => _isBlocked = blocked);
    } catch (_) {}
  }

  Future<void> _blockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Block ${_profile?.name}? They won\'t be able to message you.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await BlockService.instance.blockUser(widget.userId);
      if (mounted) {
        setState(() => _isBlocked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_profile?.name} blocked')),
        );
      }
    } catch (_) {}
  }

  Future<void> _unblockUser() async {
    try {
      await BlockService.instance.unblockUser(widget.userId);
      if (mounted) {
        setState(() => _isBlocked = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_profile?.name} unblocked')),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_notFound || _profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('User not found',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/dashboard');
                }
              },
              child: const Text('Go back'),
            ),
          ]),
        ),
      );
    }

    final user = _profile!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 16),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: Row(
          children: [
            Text(user.name),
            if (user.isVerified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF16A34A)),
            ],
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 'report') {
                showDialog(
                  context: context,
                  builder: (_) => ReportDialog(
                    targetType: 'user',
                    targetId: widget.userId,
                    targetName: user.name,
                  ),
                );
              } else if (v == 'block') {
                _blockUser();
              } else if (v == 'unblock') {
                _unblockUser();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'report', child: Text('Report User')),
              PopupMenuItem(
                value: _isBlocked ? 'unblock' : 'block',
                child: Text(_isBlocked ? 'Unblock User' : 'Block User'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + identity
            _Section(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AvatarCircle(user.initials, size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
                    const SizedBox(height: 2),
                    Text(user.role.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                            letterSpacing: 1, color: AppColors.textMuted)),
                    if ((user.bio ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(user.bio!,
                          style: const TextStyle(fontSize: 13, color: AppColors.textBody, height: 1.5)),
                    ],
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Details
            _Section(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionLabel('Details'),
                const SizedBox(height: 14),
                if ((user.university ?? '').isNotEmpty)
                  _Row(Icons.school_outlined, user.university!),
                if ((user.location ?? '').isNotEmpty)
                  _Row(Icons.location_on_outlined, user.location!),
                if ((user.portfolio ?? '').isNotEmpty)
                  _Row(Icons.link, user.portfolio!, isLink: true),
                if ([user.university, user.location, user.portfolio]
                    .every((v) => (v ?? '').isEmpty))
                  const Text('No details added.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted,
                          fontStyle: FontStyle.italic)),
                if ((user.createdAt ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Text('Member since ${_timeAgo(user.createdAt!)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ]),
            ),
            const SizedBox(height: 12),

            // Skills
            if (user.skills.isNotEmpty)
              _Section(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionLabel('Skills'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: user.skills.map((s) => SkillChip(s)).toList(),
                  ),
                ]),
              ),

            // Reviews section
            if (_reviews.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Section(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const SectionLabel('Reviews'),
                    const Spacer(),
                    Icon(Icons.star_rounded, size: 16, color: const Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(_avgRating.toStringAsFixed(1),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(' (${_reviews.length})',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  ]),
                  const SizedBox(height: 12),
                  ..._reviews.take(5).map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          ...List.generate(5, (i) => Icon(
                            i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 14,
                            color: i < r.rating ? const Color(0xFFF59E0B) : AppColors.border,
                          )),
                          const SizedBox(width: 8),
                          Text(r.reviewer?.name ?? 'Anonymous',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                        if (r.comment.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(r.comment,
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textBody)),
                        ],
                      ],
                    ),
                  )),
                ]),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String iso) {
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d);
      if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      return 'recently';
    } catch (_) {
      return '';
    }
  }
}

class _Section extends StatelessWidget {
  final Widget child;
  const _Section({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: child,
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool isLink;
  const _Row(this.icon, this.value, {this.isLink = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    color: isLink ? AppColors.accent : AppColors.textBody,
                    decoration: isLink ? TextDecoration.underline : null),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}
