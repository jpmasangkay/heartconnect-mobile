import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/notification_socket_service.dart';
import '../services/push_notification_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../models/notification.dart' as app;

class MainScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WidgetsBindingObserver {
  int _unreadChat = 0;
  int _unreadNotif = 0;
  final _notifService = NotificationService.instance;
  final _notifSocket = NotificationSocketService.instance;
  final _push = PushNotificationService.instance;

  final Set<String> _shownNotifIds = {};
  bool _firstFetch = true;
  final List<StreamSubscription> _subs = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifSocket();
    _fetch();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetch();
      _startPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 2), (_) => _fetch());
  }

  /// Connect to Socket.IO for instant notification delivery.
  Future<void> _initNotifSocket() async {
    try {
      await SocketService.instance.initSocket();
      _notifSocket.setupSocketListeners();
      
      _subs.add(_notifSocket.onNotification.listen(_onRealtimeNotification));
      
      _subs.add(_notifSocket.onUnreadCount.listen((count) {
        if (mounted && count != _unreadNotif) {
          setState(() => _unreadNotif = count);
        }
      }));

      _subs.add(_notifSocket.onChatUnread.listen((count) {
        if (mounted && count != _unreadChat) {
          setState(() => _unreadChat = count);
        }
      }));
      
      _subs.add(_notifSocket.onConnect.listen((_) {
        assert(() { debugPrint('Notification socket ready — real-time push active'); return true; }());
      }));
    } catch (e) {
      assert(() { debugPrint('Failed to init notification socket: $e'); return true; }());
    }
  }

  /// Called instantly when the server emits `notification:new`.
  void _onRealtimeNotification(app.AppNotification notif) {
    if (!mounted) return;

    // Show native push if we haven't already
    if (!_shownNotifIds.contains(notif.id)) {
      _shownNotifIds.add(notif.id);
      _push.showNotification(
        id: notif.id.hashCode,
        title: notif.title,
        body: notif.message,
        payload: notif.link ?? '/notifications',
      );
    }

    // Bump badge count immediately
    setState(() => _unreadNotif = _unreadNotif + 1);

    // Keep the set from growing unbounded
    if (_shownNotifIds.length > 200) {
      final toRemove = _shownNotifIds.take(_shownNotifIds.length - 100).toList();
      _shownNotifIds.removeAll(toRemove);
    }
  }

  /// Fallback HTTP polling for badge count accuracy.
  Future<void> _fetch() async {
    // Fire both requests in parallel — they are fully independent.
    final results = await Future.wait([
      ChatService.instance.getUnreadCount().catchError((_) => 0),
      _notifService.getUnreadCount().catchError((_) => 0),
    ]);

    final chatCount = results[0];
    final notifCount = results[1];

    if (!mounted) return;

    // ── Chat unread ──
    if (chatCount != _unreadChat) {
      if (!_firstFetch && chatCount > _unreadChat) {
        final diff = chatCount - _unreadChat;
        _push.showNotification(
          id: 'chat_unread'.hashCode,
          title: 'New Message${diff > 1 ? 's' : ''}',
          body: 'You have $diff unread message${diff > 1 ? 's' : ''}',
          payload: '/chat',
        );
      }
      setState(() => _unreadChat = chatCount);
    }

    // ── Notification unread count sync ──
    if (notifCount != _unreadNotif) {
      if (!_firstFetch && notifCount > _unreadNotif) {
        _showNewNotifications();
      }
      setState(() => _unreadNotif = notifCount);
    }

    _firstFetch = false;
  }

  /// Fetch the latest notifications and show a native push for any
  /// unread ones we haven't shown yet (fallback for missed socket events).
  Future<void> _showNewNotifications() async {
    try {
      final result = await _notifService.getNotifications(page: 1, limit: 10);
      for (final notif in result.data) {
        if (!notif.read && !_shownNotifIds.contains(notif.id)) {
          _shownNotifIds.add(notif.id);
          _push.showNotification(
            id: notif.id.hashCode,
            title: notif.title,
            body: notif.message,
            payload: notif.link ?? '/notifications',
          );
        }
      }
      // Keep the set from growing unbounded
      if (_shownNotifIds.length > 200) {
        final toRemove = _shownNotifIds.take(_shownNotifIds.length - 100).toList();
        _shownNotifIds.removeAll(toRemove);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isClient = user?.role == 'client';
    final branch = widget.navigationShell.currentIndex;

    // Map branch index → nav index (clients skip the Jobs tab)
    int navIndex = isClient
        ? switch (branch) { 0 => 0, 2 => 1, 3 => 2, _ => 0 }
        : branch;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (branch != 0) {
          widget.navigationShell.goBranch(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.parchment,
        body: widget.navigationShell,
        bottomNavigationBar: _BottomNav(
          currentIndex: navIndex,
          isClient: isClient,
          unreadChat: _unreadChat,
          unreadNotif: _unreadNotif,
          onNotif: () => context.push('/notifications'),
          onTap: (i) {
            final branchIndex = isClient
                ? switch (i) { 0 => 0, 1 => 2, 2 => 3, _ => 0 }
                : i;
            widget.navigationShell.goBranch(
              branchIndex,
              initialLocation: branchIndex == branch,
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Bottom nav
// ─────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isClient;
  final int unreadChat, unreadNotif;
  final VoidCallback onNotif;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.isClient,
    required this.unreadChat,
    required this.unreadNotif,
    required this.onNotif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Nav items
    final items = <_Item>[
      _Item(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: isClient ? 'My Jobs' : 'Home',
      ),
      if (!isClient)
        const _Item(
          icon: Icons.grid_view_outlined,
          activeIcon: Icons.grid_view_rounded,
          label: 'Browse',
        ),
      _Item(
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        label: 'Messages',
        badge: unreadChat,
      ),
      const _Item(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.rule.withValues(alpha: 0.6), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++)
                _NavItem(
                  item: items[i],
                  isActive: currentIndex == i,
                  onTap: () => onTap(i),
                ),
              // Notification bell — treated as a "ghost" tab at the right edge
              _NotifItem(count: unreadNotif, onTap: onNotif),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item {
  final IconData icon, activeIcon;
  final String label;
  final int badge;
  const _Item({required this.icon, required this.activeIcon, required this.label, this.badge = 0});
}

class _NavItem extends StatelessWidget {
  final _Item item;
  final bool isActive;
  final VoidCallback onTap;
  const _NavItem({required this.item, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: 22,
                  color: isActive ? AppColors.ink : AppColors.muted,
                ),
                if (item.badge > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: AppColors.rust,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        item.badge > 99 ? '99+' : '${item.badge}',
                        style: GoogleFonts.inter(
                          fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? AppColors.ink : AppColors.muted,
              ),
              child: Text(item.label),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: isActive ? 18 : 0,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifItem extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _NotifItem({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  count > 0 ? Icons.notifications_rounded : Icons.notifications_outlined,
                  size: 22,
                  color: count > 0 ? AppColors.rust : AppColors.muted,
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: AppColors.rust,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: GoogleFonts.inter(
                          fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text('Notifs',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w400)),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: 0,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
