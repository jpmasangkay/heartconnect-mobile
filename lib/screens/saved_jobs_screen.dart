import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/job.dart';
import '../services/saved_job_service.dart';
import '../theme/app_theme.dart';

class SavedJobsScreen extends StatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  final _service = SavedJobService();
  final _jobs = <Job>[];
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;
  bool _loadingMore = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _page < _totalPages) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _service.getSavedJobs(page: 1);
      if (mounted) {
        setState(() {
          _jobs
            ..clear()
            ..addAll(result.data);
          _page = 1;
          _totalPages = result.pages;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final result = await _service.getSavedJobs(page: _page + 1);
      if (mounted) {
        setState(() {
          _jobs.addAll(result.data);
          _page++;
          _totalPages = result.pages;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _unsave(int index) async {
    final job = _jobs[index];
    setState(() => _jobs.removeAt(index));
    try {
      await _service.unsaveJob(job.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job removed from saved')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _jobs.insert(index, job));
      }
    }
  }

  String _deadlineLabel(Job job) {
    final days = job.deadlineDays;
    if (days < 0) return 'Expired';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return '$days days left';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Jobs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_border_rounded,
                          size: 64, color: AppColors.textMuted.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      Text('No saved jobs',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Save jobs you\'re interested in to see them here',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _jobs.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _jobs.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      final job = _jobs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => context.push('/jobs/${job.id}'),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(job.title,
                                            style: GoogleFonts.dmSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              color: AppColors.navy,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.bookmark_remove_rounded,
                                            color: AppColors.accent),
                                        onPressed: () => _unsave(index),
                                        tooltip: 'Unsave',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(job.clientName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textMuted,
                                      )),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _Tag(
                                        icon: Icons.attach_money_rounded,
                                        label: '₱${job.budget.toStringAsFixed(0)}',
                                      ),
                                      const SizedBox(width: 8),
                                      _Tag(
                                        icon: Icons.schedule_rounded,
                                        label: _deadlineLabel(job),
                                        color: job.deadlineDays <= 3
                                            ? AppColors.accent
                                            : null,
                                      ),
                                      if (job.category.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        _Tag(
                                          icon: Icons.category_rounded,
                                          label: job.category,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _Tag({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
