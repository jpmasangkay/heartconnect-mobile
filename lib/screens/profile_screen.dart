import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

const _availableSkills = [
  'React', 'Vue', 'Angular', 'TypeScript', 'JavaScript', 'Python', 'Node.js',
  'Figma', 'Illustrator', 'Photoshop', 'UI/UX Design', 'Tailwind CSS',
  'Django', 'Laravel', 'MongoDB', 'PostgreSQL', 'MySQL',
  'AWS', 'Docker', 'Cybersecurity', 'Penetration Testing',
  'Content Writing', 'SEO', 'Social Media', 'Data Science', 'Machine Learning',
];

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  bool _saving = false;
  String? _error;
  String? _success;

  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _uniCtrl = TextEditingController();
  final _portfolioCtrl = TextEditingController();
  final _skillCtrl = TextEditingController();
  List<String> _skills = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _uniCtrl.dispose();
    _portfolioCtrl.dispose();
    _skillCtrl.dispose();
    super.dispose();
  }

  void _startEdit() {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    _nameCtrl.text = user.name;
    _bioCtrl.text = user.bio ?? '';
    _locationCtrl.text = user.location ?? '';
    _uniCtrl.text = user.university ?? '';
    _portfolioCtrl.text = user.portfolio ?? '';
    _skills = List.from(user.skills);
    setState(() { _editing = true; _error = null; _success = null; });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final updated = await AuthService.instance.updateProfile({
        'name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'university': _uniCtrl.text.trim(),
        'portfolio': _portfolioCtrl.text.trim(),
        'skills': _skills,
      });
      ref.read(authProvider.notifier).updateUser(updated);
      if (!mounted) return;
      setState(() { _editing = false; _saving = false; _success = 'Profile updated successfully.'; });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _success = null);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AuthService.instance.extractError(e);
      });
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
        title: const Text('Your Profile'),
        actions: [
          if (!_editing)
            TextButton.icon(
              onPressed: _startEdit,
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Edit', style: TextStyle(fontSize: 13)),
            )
          else
            TextButton(
              onPressed: () => setState(() { _editing = false; }),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ),
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            onPressed: _logout,
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_success != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  border: Border.all(color: const Color(0xFF86EFAC).withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.check, size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Text(_success!, style: const TextStyle(fontSize: 12, color: Color(0xFF15803D))),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // Unified Profile Card (Avatar + Details + Skills)
            _Section(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AvatarCircle(user.initials, size: 56),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _editing
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _Lbl('Full name'),
                            const SizedBox(height: 6),
                            TextField(controller: _nameCtrl),
                            const SizedBox(height: 12),
                            _Lbl('Bio'),
                            const SizedBox(height: 6),
                            TextField(controller: _bioCtrl, maxLines: 4,
                                decoration: const InputDecoration(
                                    hintText: 'Tell clients about yourself...',
                                    alignLabelWithHint: true)),
                          ])
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(user.name,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
                            const SizedBox(height: 2),
                            Text(user.role.toUpperCase(),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                    letterSpacing: 1, color: AppColors.textMuted)),
                            if ((user.bio ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(user.bio!,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textBody, height: 1.5)),
                            ] else
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('No bio added yet.',
                                    style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                              ),
                          ]),
                  ),
                ]),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(height: 1),
                ),

                const SectionLabel('Details'),
                const SizedBox(height: 14),
                if (_editing) ...[
                  _Lbl('Email'),
                  const SizedBox(height: 6),
                  TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: user.email,
                      fillColor: AppColors.creamDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Email cannot be changed.',
                      style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  _Lbl('Location'),
                  const SizedBox(height: 6),
                  TextField(controller: _locationCtrl,
                      decoration: const InputDecoration(hintText: 'Manila, Philippines')),
                  if (user.role == 'student') ...[
                    const SizedBox(height: 12),
                    _Lbl('University / School'),
                    const SizedBox(height: 6),
                    TextField(controller: _uniCtrl,
                        decoration: const InputDecoration(hintText: 'University of the Philippines')),
                  ],
                  const SizedBox(height: 12),
                  _Lbl('Portfolio / Website'),
                  const SizedBox(height: 6),
                  TextField(controller: _portfolioCtrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(hintText: 'https://yourportfolio.com')),
                ] else ...[
                  _DetailRow(Icons.email_outlined, user.email),
                  if ((user.location ?? '').isNotEmpty)
                    _DetailRow(Icons.location_on_outlined, user.location!),
                  if ((user.university ?? '').isNotEmpty)
                    _DetailRow(Icons.school_outlined, user.university!),
                  if ((user.portfolio ?? '').isNotEmpty)
                    _DetailRow(Icons.link, user.portfolio!, isLink: true),
                  if ([user.location, user.university, user.portfolio].every((v) => (v ?? '').isEmpty))
                    const Text('No additional details added.',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                ],

                // ── Skills ──
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                const SectionLabel('Skills'),
                const SizedBox(height: 12),
                if (_editing) ...[
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _skillCtrl,
                        decoration: const InputDecoration(hintText: 'Add a custom skill...'),
                        onSubmitted: (_) => _addCustomSkill(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _addCustomSkill,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
                      child: const Text('Add'),
                    ),
                  ]),
                  if (_skills.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: _skills
                          .map((s) => SkillChip(s, selected: true,
                              onRemove: () => setState(() => _skills.remove(s))))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text('Suggested:',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: _availableSkills
                        .where((s) => !_skills.contains(s))
                        .map((s) => GestureDetector(
                              onTap: () => setState(() => _skills = [..._skills, s]),
                              child: SkillChip('+ $s'),
                            ))
                        .toList(),
                  ),
                ] else if (user.skills.isEmpty)
                  const Text('No skills added yet.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontStyle: FontStyle.italic))
                else
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: user.skills.map((s) => SkillChip(s)).toList(),
                  ),
              ]),
            ),

            if (_editing) ...[
              const SizedBox(height: 16),
              if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 12)],
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save changes'),
              ),
            ] else ...[
              const SizedBox(height: 12),
              // Settings section
              _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Settings'),
                    const SizedBox(height: 10),
                    if (user.role == 'admin')
                      _SettingsItem(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Admin Dashboard',
                        onTap: () => context.push('/admin'),
                      ),
                    if (user.role != 'client')
                      _SettingsItem(
                        icon: Icons.bookmark_rounded,
                        label: 'Saved Jobs',
                        onTap: () => context.push('/saved-jobs'),
                      ),
                    _SettingsItem(
                      icon: Icons.star_rounded,
                      label: 'Reviews',
                      onTap: () => context.push('/reviews'),
                    ),
                    _SettingsItem(
                      icon: Icons.verified_rounded,
                      label: 'Profile Verification',
                      trailing: user.isVerified
                          ? const Text('Verified', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600))
                          : null,
                      onTap: () => context.push('/verification'),
                    ),
                    _SettingsItem(
                      icon: Icons.security_rounded,
                      label: 'Two-Factor Auth',
                      trailing: user.twoFactorEnabled
                          ? const Text('Enabled', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600))
                          : null,
                      onTap: () => context.push('/two-factor'),
                    ),
                    _SettingsItem(
                      icon: Icons.block_rounded,
                      label: 'Blocked Users',
                      onTap: () => context.push('/blocked-users'),
                    ),
                    const Divider(height: 24),
                    _SettingsItem(
                      icon: Icons.description_rounded,
                      label: 'Terms of Service',
                      onTap: () => context.push('/terms'),
                    ),
                    _SettingsItem(
                      icon: Icons.privacy_tip_rounded,
                      label: 'Privacy Policy',
                      onTap: () => context.push('/privacy'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _addCustomSkill() {
    final s = _skillCtrl.text.trim();
    if (s.isNotEmpty && !_skills.contains(s)) {
      setState(() { _skills = [..._skills, s]; _skillCtrl.clear(); });
    }
  }
}

class _Section extends StatelessWidget {
  final Widget child;
  const _Section({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppColors.cardShadow,
        ),
        child: child,
      );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool isLink;
  const _DetailRow(this.icon, this.value, {this.isLink = false});
  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: isLink ? AppColors.accent : AppColors.textBody,
                  decoration: isLink ? TextDecoration.underline : null),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
    if (!isLink) return content;
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(value);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: content,
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

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  const _SettingsItem({required this.icon, required this.label, this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textBody))),
          if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}
