import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/job_service.dart';
import '../models/job.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

final _jobServiceProvider = Provider((ref) => JobService.instance);

class JobBoardScreen extends ConsumerStatefulWidget {
  const JobBoardScreen({super.key});
  @override
  ConsumerState<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends ConsumerState<JobBoardScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _category = '';
  String _budgetMin = '';
  String _budgetMax = '';
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _loadError;
  List<Job> _jobs = [];
  List<String> _categories = [];
  StreamSubscription<void>? _socketSub;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _fetchJobs();
    _scrollCtrl.addListener(_onScroll);
    final jobService = ref.read(_jobServiceProvider);
    jobService.setupSocketListeners();
    _socketSub = jobService.onNewJob.listen((_) => _silentRefresh());
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _silentRefresh() async {
    if (_loading || _loadingMore) return;
    try {
      final result = await ref.read(_jobServiceProvider).getJobs(
        search: _searchCtrl.text.trim(),
        category: _category,
        budgetMin: _budgetMin.isNotEmpty ? double.tryParse(_budgetMin) : null,
        budgetMax: _budgetMax.isNotEmpty ? double.tryParse(_budgetMax) : null,
        page: 1,
      );
      if (mounted) setState(() { _jobs = result.jobs; _totalPages = result.pages; _page = 1; });
    } catch (_) {}
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        !_loadingMore && _page < _totalPages) {
      _loadMore();
    }
  }

  Future<void> _loadCategories() async {
    final cats = await ref.read(_jobServiceProvider).getCategories();
    if (mounted) setState(() => _categories = cats);
  }

  Future<void> _fetchJobs({bool append = false}) async {
    if (!append) setState(() => _loading = true);
    try {
      final result = await ref.read(_jobServiceProvider).getJobs(
        search: _searchCtrl.text.trim(),
        category: _category,
        budgetMin: _budgetMin.isNotEmpty ? double.tryParse(_budgetMin) : null,
        budgetMax: _budgetMax.isNotEmpty ? double.tryParse(_budgetMax) : null,
        page: _page,
      );
      if (mounted) {
        setState(() {
          _loadError = null;
          _jobs = append ? [..._jobs, ...result.jobs] : result.jobs;
          _totalPages = result.pages;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          if (append && _page > 1) _page--;
          if (!append) {
            _loadError = ref.read(_jobServiceProvider).extractError(e);
          }
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_page >= _totalPages || _loadingMore) return;
    setState(() { _loadingMore = true; _page++; });
    await _fetchJobs(append: true);
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() { _category = ''; _budgetMin = ''; _budgetMax = ''; _page = 1; });
    _fetchJobs();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(
        categories: _categories,
        selectedCategory: _category,
        budgetMin: _budgetMin,
        budgetMax: _budgetMax,
        onApply: (cat, min, max) {
          setState(() { _category = cat; _budgetMin = min; _budgetMax = max; _page = 1; });
          _fetchJobs();
          Navigator.pop(context);
        },
        onClear: () {
          _clearFilters();
          Navigator.pop(context);
        },
      ),
    );
  }

  bool get _hasFilters => _category.isNotEmpty || _budgetMin.isNotEmpty || _budgetMax.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _page = 1);
          await _fetchJobs();
        },
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 130,
              pinned: true,
              backgroundColor: AppColors.navy,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1C3A28), Color(0xFF2D5C3E)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('BROWSE OPPORTUNITIES',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white70)),
                          ),
                          const SizedBox(height: 8),
                          const Text('Find Your Next Gig',
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchBarDelegate(
                searchCtrl: _searchCtrl,
                hasFilters: _hasFilters,
                onSearch: () { setState(() => _page = 1); _fetchJobs(); },
                onFilter: _showFilterSheet,
              ),
            ),
            if (_categories.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.background,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _FilterChip(
                            label: 'All',
                            selected: _category.isEmpty,
                            onTap: () { setState(() { _category = ''; _page = 1; }); _fetchJobs(); },
                          );
                        }
                        final cat = _categories[i - 1];
                        return _FilterChip(
                          label: cat,
                          selected: _category == cat,
                          onTap: () { setState(() { _category = cat; _page = 1; }); _fetchJobs(); },
                        );
                      },
                    ),
                  ),
                ),
              ),
            if (_loading)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        height: 170,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.cardShadowLight,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SkeletonBox(height: 12, width: 80),
                          const SizedBox(height: 10),
                          const SkeletonBox(height: 18),
                          const SizedBox(height: 6),
                          SkeletonBox(height: 14, width: MediaQuery.of(context).size.width * 0.5),
                          const Spacer(),
                          const SkeletonBox(height: 12),
                        ]),
                      ),
                    ),
                    childCount: 5,
                  ),
                ),
              )
            else if (_loadError != null && _jobs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      const Text('Couldn’t load jobs',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textBody)),
                      const SizedBox(height: 8),
                      Text(_loadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.35)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _loadError = null);
                          _fetchJobs();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_jobs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: AppColors.creamDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    const Text('No jobs found', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textBody)),
                    const SizedBox(height: 6),
                    const Text('Try adjusting your filters', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: OutlinedButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Clear Filters'),
                      ),
                    ),
                  ],
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i == _jobs.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _JobCard(job: _jobs[i]),
                      );
                    },
                    childCount: _jobs.length + (_loadingMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Pinned search bar delegate ────────────────────────────────────────────────
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchCtrl;
  final bool hasFilters;
  final VoidCallback onSearch;
  final VoidCallback onFilter;

  const _SearchBarDelegate({
    required this.searchCtrl,
    required this.hasFilters,
    required this.onSearch,
    required this.onFilter,
  });

  /// Must match the SizedBox height below or pinned sliver geometry asserts fail.
  static const double _height = 68;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_SearchBarDelegate old) =>
      old.hasFilters != hasFilters;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: _height,
      child: Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search jobs...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.navy, width: 1.5)),
            ),
            onSubmitted: (_) => onSearch(),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onFilter,
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: hasFilters ? AppColors.navy : Colors.white,
              border: Border.all(color: hasFilters ? AppColors.navy : AppColors.border.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.tune_rounded, size: 20, color: hasFilters ? Colors.white : AppColors.textMuted),
                if (hasFilters)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ]),
    ),
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final String budgetMin, budgetMax;
  final void Function(String cat, String min, String max) onApply;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.categories,
    required this.selectedCategory,
    required this.budgetMin,
    required this.budgetMax,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _category;
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    _minCtrl = TextEditingController(text: widget.budgetMin);
    _maxCtrl = TextEditingController(text: widget.budgetMax);
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onClear,
                    child: const Text('Clear all', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(label: 'All', selected: _category.isEmpty, onTap: () => setState(() => _category = '')),
                  ...widget.categories.map((c) => _FilterChip(
                    label: c,
                    selected: _category == c,
                    onTap: () => setState(() => _category = c),
                  )),
                ],
              ),
              const SizedBox(height: 24),
              const Text('BUDGET (₱)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Min', prefixText: '₱ '),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('–', style: TextStyle(fontSize: 18, color: AppColors.textMuted)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Max', prefixText: '₱ '),
                  ),
                ),
              ]),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => widget.onApply(_category, _minCtrl.text, _maxCtrl.text),
                child: const Text('Apply Filters'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          border: Border.all(color: selected ? AppColors.navy : AppColors.border.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textBody)),
      ),
    );
  }
}

// ── Job Card ──────────────────────────────────────────────────────────────────
class _JobCard extends StatelessWidget {
  final Job job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final days = job.deadlineDays;
    final isNew = job.createdAt != null &&
        DateTime.now().difference(DateTime.tryParse(job.createdAt!) ?? DateTime.now()).inHours < 48;
    final isUrgent = days > 0 && days <= 3;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/jobs/${job.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: isUrgent
                ? [BoxShadow(color: Colors.red.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4))]
                : AppColors.cardShadowLight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Color stripe
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _categoryColor(job.category),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _categoryColor(job.category).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(job.category,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                color: _categoryColor(job.category))),
                      ),
                      const Spacer(),
                      if (isNew)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('NEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF92400E), letterSpacing: 0.5)),
                        ),
                      StatusBadge(job.status),
                    ]),
                    const SizedBox(height: 10),
                    Text(job.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy, height: 1.2),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(job.clientName, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    ]),
                    if (job.skills.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 6, runSpacing: 6,
                          children: job.skills.take(3).map((s) => SkillChip(s)).toList()),
                    ],
                    const SizedBox(height: 14),
                    Container(height: 1, color: AppColors.border.withValues(alpha: 0.1)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(Icons.monetization_on_outlined, size: 16, color: AppColors.navy.withValues(alpha: 0.1)),
                      const SizedBox(width: 5),
                      Text(
                        '₱${_formatNum(job.budget.toStringAsFixed(0))} ${job.budgetType}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isUrgent ? Colors.red.withValues(alpha: 0.1) : AppColors.creamDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.access_time_rounded, size: 13, color: isUrgent ? Colors.red : AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            days > 0 ? '$days days left' : 'Expired',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: isUrgent ? Colors.red : AppColors.textMuted),
                          ),
                        ]),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNum(String n) => n.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Web Development': return const Color(0xFF1e3a5f);
      case 'Graphic Design': return const Color(0xFF4a1b6e);
      case 'Cybersecurity': return const Color(0xFF0f2d1e);
      case 'Marketing': return const Color(0xFF1a3d28);
      case 'Data Science': return const Color(0xFF2a1060);
      default: return AppColors.navy;
    }
  }
}
