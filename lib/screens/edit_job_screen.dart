import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/job_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class EditJobScreen extends StatefulWidget {
  final String jobId;
  const EditJobScreen({super.key, required this.jobId});
  @override
  State<EditJobScreen> createState() => _EditJobScreenState();
}

class _EditJobScreenState extends State<EditJobScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  bool _confirmDelete = false;
  String? _error;
  String? _loadError;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _skillCtrl = TextEditingController();
  String _budgetType = 'fixed';
  String _status = 'open';
  String _category = '';
  DateTime? _deadline;
  List<String> _skills = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    _skillCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final job = await JobService.instance.getJob(widget.jobId);
      if (!mounted) return;
      setState(() {
        _titleCtrl.text = job.title;
        _descCtrl.text = job.description;
        _budgetCtrl.text = job.budget.toStringAsFixed(0);
        _budgetType = job.budgetType;
        _status = job.status;
        _category = job.category;
        _skills = List<String>.from(job.skills);
        try { _deadline = DateTime.parse(job.deadline); } catch (_) {}
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = JobService.instance.extractError(e);
        });
      }
    }
  }

  void _addSkill() {
    final s = _skillCtrl.text.trim();
    if (s.isEmpty) return;
    final dup = _skills.any((x) => x.toLowerCase() == s.toLowerCase());
    if (dup) return;
    setState(() {
      _skills = [..._skills, s];
      _skillCtrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.navy)),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty || _budgetCtrl.text.isEmpty || _deadline == null) {
      setState(() => _error = 'Please fill in all required fields.');
      return;
    }
    if (_skills.isEmpty) {
      setState(() => _error = 'Add at least one required skill.');
      return;
    }
    final budget = double.tryParse(_budgetCtrl.text.trim());
    if (budget == null || budget <= 0) {
      setState(() => _error = 'Enter a valid budget.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'budget': budget,
        'budgetType': _budgetType,
        'deadline': _deadline!.toIso8601String(),
        'status': _status,
        'skills': _skills,
        'category': _category,
      };
      await JobService.instance.updateJob(widget.jobId, payload);
      if (!mounted) return;
      context.go('/jobs/${widget.jobId}', extra: DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (mounted) {
        setState(() { _error = JobService.instance.extractError(e); _saving = false; });
      }
    }
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await JobService.instance.deleteJob(widget.jobId);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _confirmDelete = false;
          _error = JobService.instance.extractError(e);
        });
      }
    }
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

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
          ),
          title: const Text('Edit Job'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(_loadError!, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textBody)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () { setState(() { _loading = true; _loadError = null; }); _load(); },
                  child: const Text('Retry')),
            ]),
          ),
        ),
      );
    }

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
        title: const Text('Edit Job'),
        actions: [
          if (!_confirmDelete)
            TextButton.icon(
              onPressed: () => setState(() => _confirmDelete = true),
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              label: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13)),
            )
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Delete?', style: TextStyle(fontSize: 12, color: Colors.red)),
              const SizedBox(width: 6),
              TextButton(
                onPressed: _deleting ? null : _delete,
                child: Text(_deleting ? '...' : 'Yes',
                    style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => setState(() => _confirmDelete = false),
                child: const Text('No', style: TextStyle(fontSize: 12)),
              ),
            ]),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
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

              _Lbl('Job title *'),
              const SizedBox(height: 6),
              TextField(controller: _titleCtrl),

              const SizedBox(height: 14),
              _Lbl('Status'),
              const SizedBox(height: 6),
              _Dropdown<String>(
                value: _status,
                items: const ['open', 'closed', 'in-progress'],
                labels: const ['Open', 'Closed', 'In Progress'],
                onChanged: (v) => setState(() => _status = v),
              ),

              const SizedBox(height: 14),
              _Lbl('Description *'),
              const SizedBox(height: 6),
              TextField(controller: _descCtrl, maxLines: 6,
                  decoration: const InputDecoration(alignLabelWithHint: true)),

              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Lbl('Budget (₱) *'),
                  const SizedBox(height: 6),
                  TextField(controller: _budgetCtrl, keyboardType: TextInputType.number),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Lbl('Budget type'),
                  const SizedBox(height: 6),
                  _Dropdown<String>(
                    value: _budgetType,
                    items: const ['fixed', 'hourly'],
                    labels: const ['Fixed price', 'Hourly rate'],
                    onChanged: (v) => setState(() => _budgetType = v),
                  ),
                ])),
              ]),

              const SizedBox(height: 14),
              _Lbl('Application deadline *'),
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
                      _deadline == null ? 'Select a date' : '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                      style: TextStyle(
                          fontSize: 13,
                          color: _deadline == null ? AppColors.textMuted : AppColors.textBody),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 14),
              _Lbl('Required skills *'),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skillCtrl,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(hintText: 'Add a skill...'),
                      onSubmitted: (_) => _addSkill(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _addSkill,
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
                    child: const Text('Add'),
                  ),
                ],
              ),
              if (_skills.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _skills
                      .map((s) => SkillChip(
                            s,
                            onRemove: () => setState(
                              () => _skills = _skills.where((x) => x != s).toList(),
                            ),
                          ))
                      .toList(),
                ),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save changes'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/dashboard');
                  }
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Lbl extends StatelessWidget {
  final String text;
  const _Lbl(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          letterSpacing: 0.5, color: AppColors.textBody));
}

class _Dropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final List<String> labels;
  final ValueChanged<T> onChanged;
  const _Dropdown({required this.value, required this.items, required this.labels, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: List.generate(items.length,
              (i) => DropdownMenuItem(value: items[i], child: Text(labels[i], style: const TextStyle(fontSize: 13)))),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}
