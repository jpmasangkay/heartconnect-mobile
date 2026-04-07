import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../services/job_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});
  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _skillCtrl = TextEditingController();
  String _budgetType = 'fixed';
  DateTime? _deadline;
  List<String> _skills = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _budgetCtrl.dispose();
    _skillCtrl.dispose();
    super.dispose();
  }

  void _addSkill() {
    final s = _skillCtrl.text.trim();
    if (s.isNotEmpty && !_skills.contains(s)) {
      setState(() { _skills = [..._skills, s]; _skillCtrl.clear(); });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.navy),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      if (!mounted) return;
      setState(() => _error = 'Please sign in to post a job.');
      return;
    }

    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final budget = double.tryParse(_budgetCtrl.text);

    final category = _categoryCtrl.text.trim();
    if (title.length < 5) { if (!mounted) return; setState(() => _error = 'Job title must be at least 5 characters.'); return; }
    if (desc.length < 20) { if (!mounted) return; setState(() => _error = 'Description must be at least 20 characters.'); return; }
    if (category.isEmpty) { if (!mounted) return; setState(() => _error = 'Please enter a job category.'); return; }
    if (budget == null || budget <= 0) { if (!mounted) return; setState(() => _error = 'Enter a valid budget.'); return; }
    if (_deadline == null) { if (!mounted) return; setState(() => _error = 'Please select a deadline.'); return; }
    if (_skills.isEmpty) { if (!mounted) return; setState(() => _error = 'Add at least one required skill.'); return; }

    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final job = await JobService.instance.createJob({
        'title': title,
        'description': desc,
        'category': category,
        'budget': budget,
        'budgetType': _budgetType,
        'deadline': _deadline!.toIso8601String(),
        'skills': _skills,
      });
      if (!mounted) return;
      context.push('/jobs/${job.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = JobService.instance.extractError(e); });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Post a Job'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          // Stretch so nested Rows/Buttons always get bounded width.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('POST AN OPPORTUNITY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 1.5, color: AppColors.textMuted)),
            const SizedBox(height: 6),
            const Text('Create a new job listing',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.navy)),
            const SizedBox(height: 4),
            const Text('Reach talented students ready for your project.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],

                  _Label('Job title *'),
                  const SizedBox(height: 6),
                  TextField(controller: _titleCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. Build a React e-commerce store')),

                  const SizedBox(height: 16),
                  _Label('Description *'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Describe the project in detail...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: _descCtrl,
                    builder: (_, v, __) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${v.text.length} characters',
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _Label('Category *'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _categoryCtrl,
                    decoration: const InputDecoration(hintText: 'e.g. Web Development, Graphic Design'),
                    textInputAction: TextInputAction.next,
                  ),

                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _Label('Budget (₱) *'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _budgetCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '5000'),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _Label('Budget type *'),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.cream,
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _budgetType,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'fixed', child: Text('Fixed price')),
                                DropdownMenuItem(value: 'hourly', child: Text('Hourly rate')),
                              ],
                              onChanged: (v) => setState(() => _budgetType = v!),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]),

                  const SizedBox(height: 16),
                  _Label('Application deadline *'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today, size: 15, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          _deadline == null
                              ? 'Select a date'
                              : '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                          style: TextStyle(
                              fontSize: 13,
                              color: _deadline == null
                                  ? AppColors.textMuted
                                  : AppColors.textBody),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _Label('Required skills *'),
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _skillCtrl,
                        decoration: const InputDecoration(hintText: 'e.g. React, Figma...'),
                        onSubmitted: (_) => _addSkill(),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _addSkill,
                        child: const Text('Add skill'),
                      ),
                    ],
                  ),
                  if (_skills.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _skills.map((s) => SkillChip(s,
                          onRemove: () => setState(() => _skills = _skills.where((x) => x != s).toList()))).toList(),
                    ),
                  ],

                  const SizedBox(height: 16),
                  ListenableBuilder(
                    listenable: Listenable.merge([_titleCtrl, _budgetCtrl]),
                    builder: (_, __) {
                      if (_titleCtrl.text.isEmpty && _budgetCtrl.text.isEmpty) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.creamDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('PREVIEW',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                  letterSpacing: 1, color: AppColors.textMuted)),
                          const SizedBox(height: 6),
                          Text(_titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Job title',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            '₱${_budgetCtrl.text.isNotEmpty ? _budgetCtrl.text : "—"} $_budgetType · Due ${_deadline != null ? "${_deadline!.day}/${_deadline!.month}/${_deadline!.year}" : "—"}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          if (_skills.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(spacing: 4, runSpacing: 4, children: _skills.map((s) => SkillChip(s)).toList()),
                          ],
                        ]),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Post job listing'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          letterSpacing: 0.5, color: AppColors.textBody));
}
