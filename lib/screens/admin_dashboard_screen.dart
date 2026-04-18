import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../services/admin_service.dart';
import '../theme/app_theme.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final firstName = user?.name.split(' ').first ?? 'Admin';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Hi, $firstName'),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, size: 20),
              tooltip: 'Sign out',
              onPressed: _logout,
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.navy,
            tabs: const [
              Tab(text: 'Users'),
              Tab(text: 'Verifications'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: const [
            _UsersTab(),
            _VerificationsTab(),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _adminService = AdminService.instance;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _loading = true);
    try {
      final res = await _adminService.getUsers(search: _search);
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(res['data'] ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleBan(Map<String, dynamic> user) async {
    final isBanned = user['isBanned'] == true;
    final userId = user['_id'];
    try {
      if (isBanned) {
        await _adminService.unbanUser(userId);
      } else {
        await _adminService.banUser(userId);
      }
      _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_adminService.extractError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (v) {
                    setState(() => _search = v.trim());
                    _fetchUsers();
                  },
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchUsers),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView.separated(
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final user = _users[i];
                        final isBanned = user['isBanned'] == true;
                        final pendingReports = user['reportTally']?['pending'] ?? 0;
                        return ListTile(
                          title: Text(user['name'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user['email'] ?? ''),
                              Text('Role: ${user['role']} | Status: ${user['verificationStatus'] ?? 'unverified'}', 
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              if (pendingReports > 0)
                                Text('$pendingReports pending reports', style: const TextStyle(fontSize: 11, color: Colors.orange)),
                            ],
                          ),
                          trailing: user['role'] != 'admin' ? TextButton(
                            onPressed: () => _toggleBan(user),
                            child: Text(isBanned ? 'UNBAN' : 'BAN', style: TextStyle(color: isBanned ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                          ) : const SizedBox.shrink(),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _VerificationsTab extends StatefulWidget {
  const _VerificationsTab();

  @override
  State<_VerificationsTab> createState() => _VerificationsTabState();
}

class _VerificationsTabState extends State<_VerificationsTab> {
  final _adminService = AdminService.instance;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final list = await _adminService.getPendingVerifications();
      if (mounted) {
        setState(() {
          _users = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleVerification(String userId, bool approve) async {
    try {
      await _adminService.verifyUser(userId, approve);
      _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_adminService.extractError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(child: Text('No pending verifications'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final u = _users[i];
                        final docUrl = u['verificationDoc'];
                        final fullUrl = docUrl != null ? '${AppColors.staticOrigin}$docUrl' : null;
                        
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(u['email'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                                if (u['university'] != null && u['university'].toString().isNotEmpty)
                                  Text('University: ${u['university']}', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                                const SizedBox(height: 12),
                                if (fullUrl != null)
                                  GestureDetector(
                                    onTap: () async {
                                      final url = Uri.parse(fullUrl);
                                      if (await canLaunchUrl(url)) await launchUrl(url);
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: fullUrl,
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
                                        errorWidget: (context, url, err) => Container(
                                          height: 150, color: Colors.grey.shade200, 
                                          child: const Center(child: Icon(Icons.broken_image))
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _handleVerification(u['_id'], false),
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Reject'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _handleVerification(u['_id'], true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                      child: const Text('Approve'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
