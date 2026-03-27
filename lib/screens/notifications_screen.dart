import 'package:flutter/material.dart';
import '../models/notification.dart' as app;
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  final _notifications = <app.AppNotification>[];
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
      final result = await _service.getNotifications(page: 1);
      if (mounted) {
        setState(() {
          _notifications
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
      final result = await _service.getNotifications(page: _page + 1);
      if (mounted) {
        setState(() {
          _notifications.addAll(result.data);
          _page++;
          _totalPages = result.pages;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      if (mounted) {
        setState(() {
          for (int i = 0; i < _notifications.length; i++) {
            _notifications[i] = _notifications[i].copyWith(read: true);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _markRead(int index) async {
    final notif = _notifications[index];
    if (notif.read) return;
    try {
      await _service.markAsRead(notif.id);
      if (mounted) {
        setState(() {
          _notifications[index] = notif.copyWith(read: true);
        });
      }
    } catch (_) {}
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'application_new':
        return Icons.person_add_rounded;
      case 'application_status':
        return Icons.assignment_rounded;
      case 'message_new':
        return Icons.chat_bubble_rounded;
      case 'job_status':
        return Icons.work_rounded;
      case 'review_new':
        return Icons.star_rounded;
      case 'verification_status':
        return Icons.verified_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'application_new':
        return const Color(0xFF2563EB);
      case 'application_status':
        return const Color(0xFFD97706);
      case 'message_new':
        return AppColors.navy;
      case 'job_status':
        return const Color(0xFF16A34A);
      case 'review_new':
        return const Color(0xFFF59E0B);
      case 'verification_status':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.textMuted;
    }
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  void _onTap(app.AppNotification notif, int index) {
    _markRead(index);
    final link = notif.link;
    if (link != null && link.isNotEmpty) {
      context.push(link);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.read);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Mark all read',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  )),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          size: 64, color: AppColors.textMuted.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      Text('No notifications yet',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    controller: _scrollController,
                    itemCount: _notifications.length + (_loadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    padding: const EdgeInsets.only(bottom: 32),
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      final n = _notifications[index];
                      final color = _typeColor(n.type);
                      return InkWell(
                        onTap: () => _onTap(n, index),
                        child: Container(
                          color: n.read ? null : color.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(_typeIcon(n.type), size: 20, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n.title,
                                        style: GoogleFonts.inter(
                                          fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.textBody,
                                        )),
                                    const SizedBox(height: 2),
                                    Text(n.message,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppColors.textMuted,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(_timeAgo(n.createdAt),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.textMuted.withValues(alpha: 0.1),
                                        )),
                                  ],
                                ),
                              ),
                              if (!n.read)
                                Container(
                                  margin: const EdgeInsets.only(left: 8, top: 6),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
