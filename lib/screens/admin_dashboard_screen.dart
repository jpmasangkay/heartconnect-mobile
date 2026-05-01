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
    _tabCtrl = TabController(length: 3, vsync: this);
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
              Tab(text: 'Reports'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: const [
            _UsersTab(),
            _VerificationsTab(),
            _ReportsTab(),
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
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        minimumSize: const Size(0, 40),
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _handleVerification(u['_id'], true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 40),
                                      ),
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

// ── Reports Tab ───────────────────────────────────────────────────────────────

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  final _adminService = AdminService.instance;
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _adminService.getPendingReports();
      if (mounted) {
        setState(() {
          _reports = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _adminService.extractError(e);
        });
      }
    }
  }

  Future<void> _resolve(String reportId, String action) async {
    try {
      await _adminService.resolveReport(reportId, action);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'dismissed' ? 'Report dismissed' : 'Report reviewed — action taken')),
      );
      _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_adminService.extractError(e))));
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString();
    }
  }

  Color _reasonColor(String reason) {
    switch (reason.toLowerCase()) {
      case 'harassment': return Colors.red;
      case 'spam': return Colors.orange;
      case 'inappropriate': return Colors.deepOrange;
      case 'fraud': return Colors.red.shade800;
      case 'other': return Colors.blueGrey;
      default: return AppColors.navy;
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
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _fetch,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Retry'),
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _reports.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 56, color: Colors.green.shade300),
                              const SizedBox(height: 12),
                              const Text('No pending reports', style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _reports.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final r = _reports[i];
                            final reason = (r['reason'] ?? 'Unknown').toString();
                            final description = r['description']?.toString();
                            final targetType = (r['targetType'] ?? 'user').toString();
                            final reporter = r['reporter'];
                            final reporterName = reporter is Map ? (reporter['name'] ?? 'Unknown') : 'Unknown';
                            final reporterEmail = reporter is Map ? (reporter['email'] ?? '') : '';
                            final targetId = r['targetId']?.toString() ?? '';
                            final createdAt = _formatDate(r['createdAt']);

                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header row: reason chip + type badge + date
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _reasonColor(reason).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            reason,
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _reasonColor(reason)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: targetType == 'job' ? Colors.blue.shade50 : Colors.purple.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            targetType.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10, fontWeight: FontWeight.w700,
                                              color: targetType == 'job' ? Colors.blue.shade700 : Colors.purple.shade700,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(createdAt, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Reporter → Target
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(reporterName.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                              if (reporterEmail.isNotEmpty)
                                                Text(reporterEmail.toString(), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                              Text('Target: ${targetType.toUpperCase()} · ${targetId.length > 8 ? '${targetId.substring(0, 8)}…' : targetId}',
                                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Description
                                    if (description != null && description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(description, style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
                                      ),
                                    ],
                                    const SizedBox(height: 12),

                                    // Action buttons
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _resolve(r['_id'], 'dismissed'),
                                          icon: const Icon(Icons.close, size: 16),
                                          label: const Text('Dismiss'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.textMuted,
                                            minimumSize: const Size(0, 38),
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () => _resolve(r['_id'], 'reviewed'),
                                          icon: const Icon(Icons.gavel, size: 16),
                                          label: const Text('Take Action'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade600,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(0, 38),
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                          ),
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
