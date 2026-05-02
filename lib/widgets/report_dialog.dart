import 'package:flutter/material.dart';

import '../services/report_service.dart';
import '../theme/app_theme.dart';

class ReportDialog extends StatefulWidget {
  final String targetType; // 'user' or 'job'
  final String targetId;
  final String? targetName;

  const ReportDialog({
    super.key,
    required this.targetType,
    required this.targetId,
    this.targetName,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _reason;
  final _detailsController = TextEditingController();
  bool _submitting = false;
  String? _error;

  final _reasons = [
    'Spam or scam',
    'Inappropriate content',
    'Harassment or bullying',
    'Fake profile or job',
    'Misleading information',
    'Other',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      setState(() => _error = 'Please select a reason');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ReportService.instance.submitReport(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _reason!,
        details: _detailsController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report ${widget.targetType == 'user' ? 'User' : 'Job'}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.navy)),
            if (widget.targetName != null) ...[
              const SizedBox(height: 4),
              Text(widget.targetName!,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            const Text('Reason',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textBody)),
            const SizedBox(height: 8),
            ...{ for (final r in _reasons) r }.map((r) => RadioListTile<String>(
                  value: r,
                  groupValue: _reason,
                  onChanged: (v) => setState(() => _reason = v),
                  title: Text(r, style: const TextStyle(fontSize: 14)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.navy,
                )),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Additional details (optional)',
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(fontSize: 13, color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerDark),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Report'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
