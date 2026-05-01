import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../services/job_service.dart';
import '../services/application_service.dart';
import '../services/chat_service.dart';
import '../models/job.dart';
import '../models/application.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────
String _monthName(int m) => const [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][m];

String _todayLabel() {
  final n = DateTime.now();
  return '${_monthName(n.month)} ${n.day}, ${n.year}';
}

String _fmt(double v) => v
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

String _timeAgo(String? iso) {
  if (iso == null) return '';
  try {
    final d = DateTime.parse(iso);
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  } catch (_) {
    return '';
  }
}

// ─────────────────────────────────────────────
//  Root
// ─────────────────────────────────────────────
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const Center(child: CircularProgressIndicator());
    return user.role == 'client'
        ? _ClientHome(user: user)
        : _StudentHome(user: user);
  }
}

// ─────────────────────────────────────────────
//  Shared design tokens
// ─────────────────────────────────────────────
const _ink = AppColors.ink;
const _parchment = AppColors.parchment;
const _rust = AppColors.rust;
const _muted = AppColors.muted;
const _rule = AppColors.rule;

TextStyle _label(double size, {Color color = AppColors.muted, FontWeight fw = FontWeight.w500}) =>
    TextStyle(fontSize: size, color: color, fontWeight: fw);

TextStyle _serif(double size, {Color color = AppColors.ink}) =>
    TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w800);

// ─────────────────────────────────────────────
//  STUDENT HOME
// ─────────────────────────────────────────────
class _StudentHome extends ConsumerStatefulWidget {
  final User user;
  const _StudentHome({required this.user});
  @override
  ConsumerState<_StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends ConsumerState<_StudentHome> {
  List<Application> _apps = [];
  List<Job> _recommended = [];
  bool _loading = true;
  bool _recsLoading = true;
  @override
  void initState() {
    super.initState();
    _load();
    _loadRecommended();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final apps = await ApplicationService.instance.getMyApplications();
      if (mounted) setState(() { _apps = apps.where((a) => a.job != null).toList(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRecommended() async {
    try {
      final recs = await JobService.instance.getRecommended(limit: 6);
      if (mounted) setState(() { _recommended = recs; _recsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _recsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.user.name.toString().split(' ').first;
    final pending   = _apps.where((a) => a.status == 'pending').length;
    final accepted  = _apps.where((a) => a.status == 'accepted').length;
    final rejected  = _apps.where((a) => a.status == 'rejected').length;

    return Scaffold(
      backgroundColor: _parchment,
      body: RefreshIndicator(
        color: _ink,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // ── Masthead ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_todayLabel(),
                                    style: _label(11, fw: FontWeight.w600, color: _muted)
                                        .copyWith(letterSpacing: 1.2)),
                                const SizedBox(height: 6),
                                Text('Hey, $firstName.', style: _serif(30)),
                                if (widget.user.university != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(widget.user.university!,
                                        style: _label(12, color: _muted)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => context.go('/profile'),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _ink,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: _rule, thickness: 1, height: 1),
                    ],
                  ),
                ),
              ),
            ),

            // ── Stats row ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _loading
                  ? const SizedBox(height: 72, child: Center(child: CircularProgressIndicator()))
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            _StatCell(value: '${_apps.length}', label: 'Applied'),
                            _Divider(),
                            _StatCell(value: '$pending', label: 'Pending', highlight: pending > 0),
                            _Divider(),
                            _StatCell(value: '$accepted', label: 'Active', highlight: accepted > 0, color: const Color(0xFF16A34A)),
                            _Divider(),
                            _StatCell(value: '$rejected', label: 'Rejected'),
                          ],
                        ),
                      ),
                    ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: const Divider(color: _rule, thickness: 1, height: 1),
              ),
            ),

            // ── Recommended Jobs ──────────────────────────────────────
            if (!_recsLoading && _recommended.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 16, color: _rust),
                      const SizedBox(width: 8),
                      Text('Recommended for You', style: _serif(18)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _recommended.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _RecommendedJobCard(job: _recommended[i]),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: const Divider(color: _rule, thickness: 1, height: 1),
                ),
              ),
            ],

            // ── Browse CTA or section header ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Applications', style: _serif(20)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.go('/jobs'),
                      child: Text('Browse jobs →',
                          style: _label(12, color: _rust, fw: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),

            // ── List ──────────────────────────────────────────────────
            if (_loading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: _SkeletonCard(),
                  ),
                  childCount: 4,
                ),
              )
            else if (_apps.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _EmptySlate(
                    label: 'No applications yet.',
                    sub: 'Find your first job and send an application.',
                    cta: 'Browse open jobs',
                    onTap: () => context.go('/jobs'),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                    child: _StudentAppCard(app: _apps[i]),
                  ),
                  childCount: _apps.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CLIENT HOME
// ─────────────────────────────────────────────
class _ClientHome extends ConsumerStatefulWidget {
  final User user;
  const _ClientHome({required this.user});
  @override
  ConsumerState<_ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends ConsumerState<_ClientHome> {
  List<Job> _jobs = [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final jobs = await JobService.instance.getMyJobs();
      if (mounted) setState(() { _jobs = jobs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Job _patchStatus(String id, String status) =>
      _jobs.firstWhere((j) => j.id == id).let((j) => Job(
            id: j.id, title: j.title, description: j.description,
            category: j.category, budget: j.budget, budgetType: j.budgetType,
            deadline: j.deadline, skills: j.skills, status: status,
            clientUser: j.clientUser,
          ));

  Future<void> _closeJob(String id) async {
    try {
      await JobService.instance.closeJob(id);
      if (mounted) setState(() => _jobs = _jobs.map((j) => j.id == id ? _patchStatus(id, 'closed') : j).toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(JobService.instance.extractError(e))),
        );
      }
    }
  }

  Future<void> _completeJob(String id) async {
    try {
      await JobService.instance.completeJob(id);
      if (mounted) setState(() => _jobs = _jobs.map((j) => j.id == id ? _patchStatus(id, 'completed') : j).toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(JobService.instance.extractError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.user.name.toString().split(' ').first;
    final open      = _jobs.where((j) => j.status == 'open').length;
    final closed    = _jobs.where((j) => j.status == 'closed').length;
    final done      = _jobs.where((j) => j.status == 'completed').length;

    return Scaffold(
      backgroundColor: _parchment,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/post-job'),
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: Text('Post a job', style: _label(13, color: Colors.white, fw: FontWeight.w700)),
        elevation: 2,
      ),
      body: RefreshIndicator(
        color: _ink,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // ── Masthead ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_todayLabel(),
                                    style: _label(11, fw: FontWeight.w600, color: _muted)
                                        .copyWith(letterSpacing: 1.2)),
                                const SizedBox(height: 6),
                                Text('My Jobs', style: _serif(30)),
                                Text('Logged in as $firstName',
                                    style: _label(12, color: _muted)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/profile'),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(color: _ink, shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: _rule, thickness: 1, height: 1),
                    ],
                  ),
                ),
              ),
            ),

            // ── Stats ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _loading
                  ? const SizedBox(height: 72, child: Center(child: CircularProgressIndicator()))
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            _StatCell(value: '${_jobs.length}', label: 'Total'),
                            _Divider(),
                            _StatCell(value: '$open', label: 'Open', highlight: open > 0, color: const Color(0xFF16A34A)),
                            _Divider(),
                            _StatCell(value: '$closed', label: 'Closed'),
                            _Divider(),
                            _StatCell(value: '$done', label: 'Done'),
                          ],
                        ),
                      ),
                    ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: const Divider(color: _rule, thickness: 1, height: 1),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text('Postings', style: _serif(20)),
              ),
            ),

            if (_loading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: _SkeletonCard(),
                  ),
                  childCount: 3,
                ),
              )
            else if (_jobs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _EmptySlate(
                    label: "You haven't posted any jobs.",
                    sub: 'Create a listing and start receiving applications.',
                    cta: 'Post your first job',
                    onTap: () => context.push('/post-job'),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                    child: _ClientJobCard(
                      job: _jobs[i],
                      onClose: () => _closeJob(_jobs[i].id),
                      onComplete: () => _completeJob(_jobs[i].id),
                    ),
                  ),
                  childCount: _jobs.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Student app card — left-border accent
// ─────────────────────────────────────────────
class _StudentAppCard extends StatefulWidget {
  final Application app;
  const _StudentAppCard({required this.app});
  @override
  State<_StudentAppCard> createState() => _StudentAppCardState();
}

class _StudentAppCardState extends State<_StudentAppCard> {
  bool _opening = false;

  Future<void> _openChat() async {
    final job = widget.app.job!;
    setState(() => _opening = true);
    try {
      final convo = await ChatService.instance.getOrCreate(job.id, job.effectiveClientId);
      if (mounted) context.push('/chat/${convo.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ChatService.instance.extractError(e))),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final job = app.job!;
    final borderColor = _statusAccent(app.status);

    return GestureDetector(
      onTap: () => context.push('/jobs/${job.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: borderColor, width: 3)),
          boxShadow: [
            BoxShadow(color: _ink.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(job.title,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _ink),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            _InlineStatus(app.status),
          ]),
          const SizedBox(height: 4),
          Text('${job.category}  ·  ₱${_fmt(app.proposedRate)} proposed  ·  ${_timeAgo(app.createdAt)}',
              style: _label(11, color: _muted)),
          if (app.status == 'accepted') ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _openChat,
              child: Row(children: [
                _opening
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: _rust))
                    : const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: _rust),
                const SizedBox(width: 6),
                Text('Message client', style: _label(12, color: _rust, fw: FontWeight.w600)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

Color _statusAccent(String s) {
  switch (s.toLowerCase()) {
    case 'accepted':  return const Color(0xFF16A34A);
    case 'pending':   return const Color(0xFFD97706);
    case 'rejected':  return const Color(0xFFDC2626);
    case 'withdrawn': return _muted;
    case 'completed':
    case 'finished':  return const Color(0xFF7C3AED);
    default:          return _rule;
  }
}

// ─────────────────────────────────────────────
//  Client job card
// ─────────────────────────────────────────────
class _ClientJobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onClose, onComplete;
  const _ClientJobCard({required this.job, required this.onClose, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final hasApps = (job.applicationsCount ?? 0) > 0;
    final borderColor = _statusAccent(job.status);

    return GestureDetector(
      onTap: () => context.push('/jobs/${job.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: borderColor, width: 3)),
          boxShadow: [
            BoxShadow(color: _ink.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(job.title,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _ink),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            _InlineStatus(job.status),
          ]),
          const SizedBox(height: 4),
          Text('${job.category}  ·  ₱${_fmt(job.budget)} ${job.budgetType}',
              style: _label(11, color: _muted)),
          if (hasApps) ...[
            const SizedBox(height: 6),
            Row(children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: _rust, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${job.applicationsCount} application${job.applicationsCount != 1 ? 's' : ''}',
                  style: _label(12, color: _rust, fw: FontWeight.w600)),
            ]),
          ],
          const SizedBox(height: 14),
          Row(children: [
            _TinyBtn(label: 'View', onTap: () => context.push('/jobs/${job.id}')),
            if (job.status != 'completed') ...[
              const SizedBox(width: 8),
              _TinyBtn(label: 'Edit', onTap: () => context.push('/jobs/${job.id}/edit')),
            ],
            if (job.status == 'open') ...[
              const SizedBox(width: 8),
              _TinyBtn(label: 'Close', onTap: onClose, danger: true),
            ],
            if (job.status == 'closed') ...[
              const SizedBox(width: 8),
              _TinyBtn(label: 'Mark done', onTap: onComplete, accent: true),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Stat cell
// ─────────────────────────────────────────────
class _StatCell extends StatelessWidget {
  final String value, label;
  final bool highlight;
  final Color? color;
  const _StatCell({required this.value, required this.label, this.highlight = false, this.color});

  @override
  Widget build(BuildContext context) {
    final c = highlight ? (color ?? _rust) : _ink;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(children: [
          Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
          const SizedBox(height: 2),
          Text(label, style: _label(10, fw: FontWeight.w600).copyWith(letterSpacing: 0.8)),
        ]),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, color: _rule, margin: const EdgeInsets.symmetric(vertical: 14));
}

// ─────────────────────────────────────────────
//  Inline status pill — text-only, no background
// ─────────────────────────────────────────────
class _InlineStatus extends StatelessWidget {
  final String status;
  const _InlineStatus(this.status);

  @override
  Widget build(BuildContext context) {
    final color = _statusAccent(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        status.toUpperCase(),
        style: _label(9, color: color, fw: FontWeight.w700).copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tiny action button
// ─────────────────────────────────────────────
class _TinyBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger, accent;
  const _TinyBtn({required this.label, required this.onTap, this.danger = false, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final c = danger ? const Color(0xFFDC2626) : accent ? const Color(0xFF7C3AED) : _ink;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: c.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label, style: _label(11, color: c, fw: FontWeight.w600)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Empty slate
// ─────────────────────────────────────────────
class _EmptySlate extends StatelessWidget {
  final String label, sub, cta;
  final VoidCallback onTap;
  const _EmptySlate({required this.label, required this.sub, required this.cta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: _rule),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 6),
        Text(sub, style: _label(13, color: _muted)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onTap,
          child: Row(children: [
            Text(cta, style: _label(13, color: _rust, fw: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_rounded, size: 14, color: _rust),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Recommended job card (horizontal scroll)
// ─────────────────────────────────────────────
class _RecommendedJobCard extends StatelessWidget {
  final Job job;
  const _RecommendedJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/jobs/${job.id}'),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _rule.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: _ink.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 12, color: _rust.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text('AI Match', style: _label(9, color: _rust, fw: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Text(job.title,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _ink),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text('${job.category}  ·  ₱${_fmt(job.budget)}',
                style: _label(11, color: _muted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Skeleton card
// ─────────────────────────────────────────────
class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: _rule, width: 3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 14, width: 180, color: _rule),
        const SizedBox(height: 10),
        Container(height: 10, width: 120, color: _rule.withValues(alpha: 0.5)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Extension helper
// ─────────────────────────────────────────────
extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
