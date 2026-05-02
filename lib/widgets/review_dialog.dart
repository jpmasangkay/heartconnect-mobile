import 'package:flutter/material.dart';

import '../models/user.dart';
import '../models/job.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';

class ReviewDialog extends StatefulWidget {
  final Job job;
  final User reviewee;
  final VoidCallback? onSubmitted;

  const ReviewDialog({
    super.key,
    required this.job,
    required this.reviewee,
    this.onSubmitted,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Please select a rating');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ReviewService.instance.createReview(
        jobId: widget.job.id,
        revieweeId: widget.reviewee.id,
        rating: _rating,
        comment: _commentController.text.trim(),
      );
      if (mounted) {
        widget.onSubmitted?.call();
        Navigator.of(context).pop(true);
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
          children: [
            const Text('Leave a Review',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.navy)),
            const SizedBox(height: 4),
            Text('for ${widget.reviewee.name}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 6),
            Text(widget.job.title,
                style: const TextStyle(
                    color: AppColors.textBody, fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starIndex = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedScale(
                      scale: _rating >= starIndex ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        _rating >= starIndex ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 40,
                        color: _rating >= starIndex
                            ? AppColors.star
                            : AppColors.border,
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Text(
                ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'][_rating],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.star,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Write a comment (optional)',
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
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Submit'),
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
