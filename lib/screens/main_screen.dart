import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';

const _ink = Color(0xFF1C3A28);
const _parchment = Color(0xFFF8F5EE);
const _muted = Color(0xFF7A8C7B);
const _rust = Color(0xFFC4622A);
const _rule = Color(0xFFCDD9C6);

class MainScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _unreadChat = 0;
  int _unreadNotif = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final c = await ChatService().getUnreadCount();
      if (mounted && c != _unreadChat) setState(() => _unreadChat = c);
    } catch (_) {}
    try {
      final n = await NotificationService().getUnreadCount();
      if (mounted && n != _unreadNotif) setState(() => _unreadNotif = n);
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
        backgroundColor: _parchment,
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
        border: Border(top: BorderSide(color: _rule.withValues(alpha: 0.6), width: 1)),
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
                  color: isActive ? _ink : _muted,
                ),
                if (item.badge > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: _rust,
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
                color: isActive ? _ink : _muted,
              ),
              child: Text(item.label),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: isActive ? 18 : 0,
              decoration: BoxDecoration(
                color: _ink,
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
    return SizedBox(
      width: 52,
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
                  color: count > 0 ? _rust : _muted,
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: _rust,
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
                style: GoogleFonts.inter(fontSize: 10, color: _muted, fontWeight: FontWeight.w400)),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
