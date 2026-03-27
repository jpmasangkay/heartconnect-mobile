import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/job_service.dart';
import '../services/application_service.dart';
import '../services/chat_service.dart';
import '../services/review_service.dart';
import '../models/job.dart';
import '../models/application.dart';
import '../models/review.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/review_dialog.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});
  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  Job? _job;
  List<Application> _applications = [];
  Application? _myApplication;
  List<Review> _reviews = [];
  bool _hasReviewed = false;
  bool _loading = true;
  bool _applying = false;
  final _coverCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  String? _formError;
  bool _applied = false;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _coverCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _silentRefresh() async {
    if (_loading) return;
    final auth = ref.read(authProvider);
    try {
      final jobSvc = JobService();
      final appSvc = ApplicationService();
      final job = await jobSvc.getJob(widget.jobId);
      List<Application> apps = _applications;
      Application? mine = _myApplication;
      if (auth.user?.role == 'client') {
        apps = await appSvc.getForJob(widget.jobId);
      } else if (auth.user?.role == 'student' && mine == null && !_applied) {
        final myApps = await appSvc.getMyApplications();
        mine = myApps.where((a) => a.job?.id == widget.jobId).firstOrNull;
      }
      if (mounted) {
        setState(() { _job = job; _applications = apps; if (mine != null) _myApplication = mine; });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    try {
      final jobSvc = JobService();
      final appSvc = ApplicationService();
      final results = await Future.wait([
        jobSvc.getJob(widget.jobId),
        appSvc.getForJob(widget.jobId),
        if (auth.user?.role == 'student') appSvc.getMyApplications(),
        ReviewService().getJobReviews(widget.jobId),
      ]);
      final job = results[0] as Job;
      List<Application> apps = [];
      Application? mine;
      List<Review> reviews = [];
      if (auth.user?.role == 'client') {
        apps = results[1] as List<Application>;
        reviews = results.last as List<Review>;
      } else if (auth.user?.role == 'student') {
        final myApps = results[2] as List<Application>;
        mine = myApps.where((a) => a.job?.id == widget.jobId).firstOrNull;
        reviews = results.last as List<Review>;
      }
      // Determine if current user already left a review for this job
      final myId = auth.user?.id;
      final alreadyReviewed = reviews.any((r) => r.reviewer?.id == myId);
      if (mounted) {
        setState(() {
          _job = job;
          _applications = apps;
          _myApplication = mine;
          _reviews = reviews;
          _hasReviewed = alreadyReviewed;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apply() async {
    if (_coverCtrl.text.trim().isEmpty) { setState(() => _formError = 'Cover letter is required'); return; }
    final rate = double.tryParse(_rateCtrl.text);
    if (rate == null || rate <= 0) { setState(() => _formError = 'Enter a valid proposed rate'); return; }
    setState(() { _applying = true; _formError = null; });
    try {
      final app = await ApplicationService().apply(widget.jobId, _coverCtrl.text.trim(), rate);
      setState(() { _myApplication = app; _applied = true; _applying = false; });
    } catch (e) {
      setState(() { _formError = ApplicationService().extractError(e); _applying = false; });
    }
  }

  Future<void> _updateStatus(String appId, String status) async {
    try {
      final updated = await ApplicationService().updateStatus(appId, status);
      setState(() { _applications = _applications.map((a) => a.id == appId ? updated : a).toList(); });
    } catch (_) {}
  }

  Future<void> _messageApplicant(String applicantId) async {
    try {
      final convo = await ChatService().getOrCreate(widget.jobId, applicantId);
      if (mounted) context.push('/chat/${convo.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ChatService().extractError(e))),
      );
    }
  }

  Future<void> _withdraw() async {
    if (_myApplication == null) return;
    try {
      final updated = await ApplicationService().withdraw(_myApplication!.id);
      setState(() => _myApplication = updated);
    } catch (_) {}
  }

  void _showApplySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        final nav = Navigator.of(sheetCtx);
        return _ApplySheet(
          job: _job!,
          coverCtrl: _coverCtrl,
          rateCtrl: _rateCtrl,
          applying: _applying,
          formError: _formError,
          onApply: () async {
            await _apply();
            if (_applied && nav.canPop()) nav.pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.navy, iconTheme: const IconThemeData(color: Colors.white)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_job == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(),
        body: const Center(child: Text('Job not found')),
      );
    }

    final job = _job!;
    final isOwner = user?.id == job.effectiveClientId;
    final isStudent = user?.role == 'student';
    final days = job.deadlineDays;
    final canApply = isStudent && job.status == 'open' && _myApplication == null && !_applied;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        edgeOffset: 120,
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: _gradientColor(job.category),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/jobs');
                }
              },
            ),
            actions: isOwner
                ? [
                    TextButton.icon(
                      onPressed: () => context.push('/jobs/${job.id}/edit'),
                      icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
                      label: const Text('Edit', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                    )
                  ]
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_gradientColor(job.category), _gradientColor(job.category).withValues(alpha: 0.1)],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, canApply ? 100 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header card
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _gradientColor(job.category).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(job.category,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _gradientColor(job.category))),
                        ),
                        const Spacer(),
                        StatusBadge(job.status),
                      ]),
                      const SizedBox(height: 10),
                      Text(job.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.navy, height: 1.2)),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('Posted by ${job.clientName}', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      ]),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: _MetaTile(
                            icon: Icons.monetization_on_outlined,
                            label: 'Budget',
                            value: '₱${_fmt(job.budget.toStringAsFixed(0))} ${job.budgetType}',
                            accent: true,
                          ),
                        ),
                        Container(width: 1, height: 40, color: AppColors.border),
                        Expanded(
                          child: _MetaTile(
                            icon: Icons.access_time_rounded,
                            label: 'Deadline',
                            value: days > 0 ? '$days days left' : 'Expired',
                            danger: days <= 3 && days > 0,
                          ),
                        ),
                        if (!isOwner) ...[
                          Container(width: 1, height: 40, color: AppColors.border),
                          Expanded(
                            child: _MetaTile(
                              icon: Icons.people_outline_rounded,
                              label: 'Applicants',
                              value: '${job.applicationsCount ?? 0}',
                            ),
                          ),
                        ],
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SectionLabel('Description'),
                      const SizedBox(height: 12),
                      Text(job.description,
                          style: const TextStyle(fontSize: 14, color: AppColors.textBody, height: 1.65)),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Skills
                  if (job.skills.isNotEmpty)
                    _Card(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SectionLabel('Required Skills'),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: job.skills.map((s) => SkillChip(s)).toList()),
                      ]),
                    ),
                  const SizedBox(height: 12),

                  // Student: application status or withdraw
                  if (isStudent && job.status == 'open' && (_myApplication != null || _applied))
                    _myApplicationStatus(context),
                  if (isStudent && job.status == 'open' && (_myApplication != null || _applied))
                    const SizedBox(height: 12),

                  // Client: applications
                  if (isOwner) ...[_clientApplications(context), const SizedBox(height: 12)],

                  // Completed job: leave a review prompt
                  if (job.status == 'completed') ...[
                    _buildReviewPrompt(context, job, isOwner, isStudent),
                    const SizedBox(height: 12),
                  ],

                  // Reviews
                  if (_reviews.isNotEmpty) ...[
                    _Card(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const SectionLabel('Reviews'),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(10)),
                            child: Text('${_reviews.length}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        ..._reviews.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              ...List.generate(5, (i) => Icon(
                                i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 14,
                                color: i < r.rating ? const Color(0xFFF59E0B) : AppColors.border,
                              )),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r.reviewer?.name ?? 'Anonymous',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textBody),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                            if (r.comment.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(r.comment, style: const TextStyle(fontSize: 13, color: AppColors.textBody, height: 1.5)),
                            ],
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                          ]),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // About client
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SectionLabel('About the Client'),
                      const SizedBox(height: 12),
                      Row(children: [
                        AvatarCircle(job.clientName.isNotEmpty ? job.clientName[0].toUpperCase() : '?', size: 44),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(job.clientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.navy)),
                          const Text('Client', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ]),
                      ]),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),

      // Sticky Apply button (students only)
      bottomNavigationBar: canApply
          ? StickyBottomBar(
              child: MobileActionButton(
                label: 'Apply for this Job',
                icon: Icons.send_rounded,
                onPressed: auth.isAuthenticated
                    ? () => _showApplySheet(context)
                    : () => context.go('/login'),
              ),
            )
          : null,
    );
  }

  Widget _buildReviewPrompt(BuildContext context, Job job, bool isOwner, bool isStudent) {
    // Already reviewed
    if (_hasReviewed) {
      return _Card(
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
            child: const Icon(Icons.star_rounded, color: Color(0xFF16A34A), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Review Submitted', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy)),
              SizedBox(height: 2),
              Text('Thanks for your feedback!', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
        ]),
      );
    }

    // Client: review the accepted student
    if (isOwner) {
      final acceptedApp = _applications.where((a) => a.status == 'accepted').firstOrNull;
      final student = acceptedApp?.applicant;
      if (student == null) return const SizedBox.shrink();
      return _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Rate the Student'),
          const SizedBox(height: 6),
          Text('How did ${student.name} do on this job?',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 14),
          MobileActionButton(
            label: 'Leave a Review',
            icon: Icons.rate_review_rounded,
            onPressed: () async {
              final submitted = await showDialog<bool>(
                context: context,
                builder: (_) => ReviewDialog(job: job, reviewee: student),
              );
              if (submitted == true) {
                setState(() => _hasReviewed = true);
                await _load();
              }
            },
          ),
        ]),
      );
    }

    // Student: review the client if their application was accepted
    if (isStudent && _myApplication?.status == 'accepted') {
      final client = job.clientUser;
      if (client == null) return const SizedBox.shrink();
      return _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Rate the Client'),
          const SizedBox(height: 6),
          Text('How was your experience working with ${client.name}?',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 14),
          MobileActionButton(
            label: 'Leave a Review',
            icon: Icons.rate_review_rounded,
            onPressed: () async {
              final submitted = await showDialog<bool>(
                context: context,
                builder: (_) => ReviewDialog(job: job, reviewee: client),
              );
              if (submitted == true) {
                setState(() => _hasReviewed = true);
                await _load();
              }
            },
          ),
        ]),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _myApplicationStatus(BuildContext context) {
    if (_applied) {
      return _Card(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 28),
          ),
          const SizedBox(height: 12),
          const Text('Application Submitted!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy)),
          const SizedBox(height: 4),
          const Text('The client will review your application and get back to you.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
        ]),
      );
    }

    final status = _myApplication!.status;
    return _Card(
      child: Column(children: [
        StatusBadge(status),
        const SizedBox(height: 6),
        Text('Applied ${_timeAgo(_myApplication!.createdAt ?? '')}',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        if (status == 'pending') ...[
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: _withdraw,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red, width: 1.5),
              minimumSize: const Size(double.infinity, 46),
            ),
            child: const Text('Withdraw Application'),
          ),
        ],
        if (status == 'accepted') ...[
          const SizedBox(height: 14),
          MobileActionButton(
            label: 'Message Client',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: () => _messageApplicant(_job!.effectiveClientId),
            color: AppColors.accent,
          ),
        ],
      ]),
    );
  }

  Widget _clientApplications(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SectionLabel('Applications'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(10)),
            child: Text('${_applications.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 14),
        if (_applications.isEmpty)
          const Text('No applications yet. Share your job to get more visibility.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted))
        else
          ..._applications.map((app) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AppCard(app: app, onAccept: () => _updateStatus(app.id, 'accepted'),
                onReject: () => _updateStatus(app.id, 'rejected'), onMessage: () => _messageApplicant(app.applicant!.id)),
          )),
      ]),
    );
  }

  Color _gradientColor(String cat) {
    switch (cat) {
      case 'Web Development': return const Color(0xFF1e3a5f);
      case 'Graphic Design': return const Color(0xFF2d1b4e);
      case 'Cybersecurity': return const Color(0xFF0f2d1e);
      case 'Marketing': return const Color(0xFF1a3d28);
      case 'Data Science': return const Color(0xFF2a1060);
      default: return AppColors.navy;
    }
  }

  String _fmt(String n) => n.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _timeAgo(String iso) {
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return '${diff.inMinutes}m ago';
    } catch (_) { return ''; }
  }
}

// ── Apply bottom sheet ────────────────────────────────────────────────────────
class _ApplySheet extends StatefulWidget {
  final Job job;
  final TextEditingController coverCtrl, rateCtrl;
  final bool applying;
  final String? formError;
  final Future<void> Function() onApply;

  const _ApplySheet({
    required this.job,
    required this.coverCtrl,
    required this.rateCtrl,
    required this.applying,
    required this.formError,
    required this.onApply,
  });

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.applying || _submitting;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 20),
              const Text('Apply for this Job', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
              const SizedBox(height: 4),
              Text('Applying to: ${widget.job.title}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 20),
              if (widget.formError != null) ...[ErrorBanner(widget.formError!), const SizedBox(height: 14)],
              const Text('Proposed Rate (₱)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textBody)),
              const SizedBox(height: 8),
              TextField(
                controller: widget.rateCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: widget.job.budget.toStringAsFixed(0),
                  prefixText: '₱ ',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Cover Letter',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textBody)),
              const SizedBox(height: 8),
              TextField(
                controller: widget.coverCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Describe your experience and why you\'re the best fit...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              MobileActionButton(
                label: 'Submit Application',
                icon: Icons.send_rounded,
                loading: isLoading,
                onPressed: isLoading ? null : () async {
                  setState(() => _submitting = true);
                  await widget.onApply();
                  if (mounted) setState(() => _submitting = false);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── App Card (client view) ────────────────────────────────────────────────────
class _AppCard extends StatelessWidget {
  final Application app;
  final VoidCallback onAccept, onReject, onMessage;
  const _AppCard({required this.app, required this.onAccept, required this.onReject, required this.onMessage});

  @override
  Widget build(BuildContext context) {
    final applicant = app.applicant;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadowLight,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AvatarCircle(applicant?.initials ?? '?', size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: () => context.push('/users/${applicant?.id}'),
                child: Text(applicant?.name ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy)),
              ),
              Text(applicant?.university ?? applicant?.email ?? '',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₱${app.proposedRate.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy)),
            const SizedBox(height: 4),
            StatusBadge(app.status),
          ]),
        ]),
        const SizedBox(height: 10),
        Text(app.coverLetter,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
            maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        if (app.status == 'pending')
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ),
          ])
        else
          OutlinedButton.icon(
            onPressed: onMessage,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
            label: const Text('Send Message'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
          ),
      ]),
    );
  }
}

class _MetaTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool accent, danger;
  const _MetaTile({required this.icon, required this.label, required this.value, this.accent = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final c = danger ? Colors.red : (accent ? AppColors.navy : AppColors.textBody);
    return Column(children: [
      Icon(icon, size: 18, color: c.withValues(alpha: 0.1)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
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
}
