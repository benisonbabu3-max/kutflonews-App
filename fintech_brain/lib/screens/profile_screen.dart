import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/article_repository.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../utils/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repo = ArticleRepository.instance;
  final _supa = SupabaseService.instance;
  UserProfile _profile = const UserProfile();
  bool _loading = true;
  bool _saving = false;

  // Controllers
  late TextEditingController _nameCtrl, _emailCtrl, _roleCtrl, _locationCtrl, _goalCtrl;

  // Interest state
  final List<String> _allInterests = [
    'Payments', 'Regulation', 'Product', 'AI & Tech', 'Startups',
    'Geopolitics', 'Banking', 'Macro / Finance', 'Cybersecurity',
    'Strategy', 'Career / PM', 'Crypto / Web3', 'Insurtech', 'Wealthtech',
  ];
  late List<String> _selectedInterests;

  // AI toggles
  late bool _aiEnrichment, _aiInline, _aiBriefs, _aiWeekly;
  late bool _notifyMorning, _notifyEvening;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _roleCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _goalCtrl = TextEditingController();
    _selectedInterests = [];
    _aiEnrichment = true; _aiInline = true; _aiBriefs = true; _aiWeekly = true;
    _notifyMorning = true; _notifyEvening = true;
    _loadProfile();
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl,_emailCtrl,_roleCtrl,_locationCtrl,_goalCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final p = await _repo.getProfile();
    if (!mounted) return;
    setState(() {
      _profile = p;
      _nameCtrl.text = p.name;
      _emailCtrl.text = p.email.isNotEmpty ? p.email : (_supa.currentUser?.email ?? '');
      _roleCtrl.text = p.role;
      _locationCtrl.text = p.location;
      _goalCtrl.text = p.careerGoal;
      _selectedInterests = List.from(p.interests);
      _aiEnrichment = p.aiEnrichment; _aiInline = p.aiInline;
      _aiBriefs = p.aiBriefs; _aiWeekly = p.aiWeeklyDigest;
      _notifyMorning = p.notifyMorning; _notifyEvening = p.notifyEvening;
      _loading = false;
    });
  }


  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = _profile.copyWith(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      role: _roleCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      careerGoal: _goalCtrl.text.trim(),
      interests: _selectedInterests,
      notifyMorning: _notifyMorning, notifyEvening: _notifyEvening,
      aiEnrichment: _aiEnrichment, aiInline: _aiInline,
      aiBriefs: _aiBriefs, aiWeeklyDigest: _aiWeekly,
    );
    await _repo.saveProfile(updated);
    await NotificationService.scheduleDailyReminders(
      morningHour: updated.morningHour, eveningHour: updated.eveningHour);
    if (!mounted) return;
    setState(() { _profile = updated; _saving = false; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Settings saved ✓', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.nearBlack, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: AppColors.base,
      body: Center(child: CircularProgressIndicator(color: AppColors.accent)));

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildIdentityHeader()),
            SliverToBoxAdapter(child: _buildSectionLabel('PERSONAL INFO')),
            SliverToBoxAdapter(child: _buildPersonalInfo()),
            SliverToBoxAdapter(child: _buildSectionLabel('MY INTERESTS')),
            SliverToBoxAdapter(child: _buildInterestsSection()),
            SliverToBoxAdapter(child: _buildSectionLabel('AI ENGINE')),
            SliverToBoxAdapter(child: _buildAiSection()),
            SliverToBoxAdapter(child: _buildSectionLabel('NOTIFICATIONS')),
            SliverToBoxAdapter(child: _buildNotifications()),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.nearBlack,
                    foregroundColor: AppColors.base,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.base))
                    : const Text('Save all settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Inter')),
                )),
            )),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 1.5))),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(width: 60, height: 60,
            decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle,
              border: Border.all(color: AppColors.nearBlack, width: 1.5)),
            alignment: Alignment.center,
            child: Text(_profile.initials,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Inter'))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_profile.name.isNotEmpty ? _profile.name : 'Your Name',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                color: AppColors.textPrimary, letterSpacing: -.3, fontFamily: 'Inter')),
            Text(_profile.role.isNotEmpty ? '${_profile.role} · ${_profile.location}' : 'Set your role',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.textSecondary, fontFamily: 'Inter')),
          ])),
        ]),
        const SizedBox(height: 12),
        // Identity badges
        FutureBuilder(future: _repo.getStats(), builder: (ctx, snap) {
          final stats = snap.data;
          if (stats == null) return const SizedBox();
          return Wrap(spacing: 7, runSpacing: 7, children: [
            _Badge('🔥 ${stats.streak}-day streak', AppColors.accent.withOpacity(.12), const Color(0xFF8A2A10), const Color(0xFFD4895A)),
            _Badge('📚 ${stats.totalRead} read', AppColors.regulation.withOpacity(.1), AppColors.regulation, AppColors.regulation.withOpacity(.4)),
            _Badge('⭐ ${stats.topPercentile}', AppColors.success.withOpacity(.1), AppColors.success, AppColors.success.withOpacity(.4)),
          ]);
        }),
        const SizedBox(height: 12),
        // Stats row
        FutureBuilder(future: _repo.getStats(), builder: (ctx, snap) {
          final stats = snap.data;
          return Row(children: [
            _StatCell('${stats?.totalRead ?? 0}', 'Read'),
            _divider(),
            _StatCell('${stats?.totalSaved ?? 0}', 'Saved'),
            _divider(),
            _StatCell('${stats?.streak ?? 0}', 'Streak'),
          ]);
        }),
        const SizedBox(height: 12),
        // Account row — Google email + sign out
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.borderLight, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(width: 28, height: 28,
              decoration: BoxDecoration(color: AppColors.base, shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderLight, width: 1)),
              alignment: Alignment.center,
              child: const Text('G', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                color: AppColors.accent, fontFamily: 'Inter'))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Signed in with Google', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                color: AppColors.textMuted, letterSpacing: .05, fontFamily: 'Inter')),
              Text(_supa.currentUser?.email ?? 'Unknown account', style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Inter'),
                overflow: TextOverflow.ellipsis),
            ])),
            GestureDetector(
              onTap: _signOut,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: AppColors.nearBlack, borderRadius: BorderRadius.circular(10)),
                child: const Text('Sign out', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.base, fontFamily: 'Inter'))),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Sign out?', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800)),
        content: const Text('Your data is saved to your account and will be here when you sign back in.',
          style: TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out', style: TextStyle(fontFamily: 'Inter', color: AppColors.accentDark, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true) await _supa.signOut();
  }

  Widget _buildPersonalInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        _FieldRow(icon: Icons.person_outline_rounded, label: 'Full name', controller: _nameCtrl, hint: 'Benison Babu'),
        const Divider(height: 0, indent: 16, endIndent: 16),
        _FieldRow(icon: Icons.mail_outline_rounded, label: 'Email', controller: _emailCtrl, hint: 'you@email.com', keyboardType: TextInputType.emailAddress),
        const Divider(height: 0, indent: 16, endIndent: 16),
        _FieldRow(icon: Icons.work_outline_rounded, label: 'Role', controller: _roleCtrl, hint: 'Product Manager'),
        const Divider(height: 0, indent: 16, endIndent: 16),
        _FieldRow(icon: Icons.location_on_outlined, label: 'Location', controller: _locationCtrl, hint: 'Kerala, India'),
        const Divider(height: 0, indent: 16, endIndent: 16),
        _FieldRow(icon: Icons.flag_outlined, label: 'Career goal', controller: _goalCtrl, hint: 'Senior PM in Fintech by 2026'),
      ]),
    );
  }

  Widget _buildInterestsSection() {
    final previewArticles = _selectedInterests.take(4).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderLight, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Wrap(spacing: 7, runSpacing: 7,
              children: _allInterests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                final color = AppColors.forTopic(interest);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) { _selectedInterests.remove(interest); }
                    else { _selectedInterests.add(interest); }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? color : AppColors.base,
                      border: Border.all(color: isSelected ? color : AppColors.borderLight, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(interest,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Inter',
                        color: isSelected ? Colors.white : AppColors.nearBlack)),
                  ),
                );
              }).toList()),
          ),
        ]),
      ),
      // Tomorrow's feed preview
      if (_selectedInterests.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.base,
            border: Border.all(color: AppColors.borderLight, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TOMORROW\'S FEED PREVIEW',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary, letterSpacing: .07, fontFamily: 'Inter')),
            const SizedBox(height: 8),
            ...previewArticles.map((topic) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 7, top: 2),
                  decoration: BoxDecoration(color: AppColors.forTopic(topic), shape: BoxShape.circle)),
                Expanded(child: Text(
                  _previewForTopic(topic),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary, height: 1.4, fontFamily: 'Inter'))),
              ]),
            )),
          ]),
        ),
      ],
    ]);
  }

  Widget _buildAiSection() {
    return Column(children: [
      // Managed AI status card
      Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          border: Border.all(color: AppColors.success.withOpacity(.4), width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 10, height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success,
                boxShadow: [BoxShadow(color: AppColors.success.withOpacity(.4), blurRadius: 6, spreadRadius: 1)])),
            const SizedBox(width: 8),
            const Expanded(child: Text('AI is managed — nothing to set up',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                color: Color(0xFF1A5A3A), fontFamily: 'Inter'))),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Fintech Brain runs on NVIDIA NIM behind the scenes. Summaries are '
            'generated once per article and shared across all users — so the '
            'app stays free and fast for everyone.',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
              color: Color(0xFF2A5A3A), height: 1.55, fontFamily: 'Inter')),
          const SizedBox(height: 10),
          Wrap(spacing: 5, runSpacing: 5, children: [
            _flowStep('You open feed'),
            _flowArr(),
            _flowStep('Cache hit?'),
            _flowArr('yes →'),
            _flowStep('Instant, free'),
          ]),
          const SizedBox(height: 5),
          Wrap(spacing: 5, runSpacing: 5, children: [
            _flowStep('Cache hit?'),
            _flowArr('no →'),
            _flowStep('NVIDIA NIM'),
            _flowArr(),
            _flowStep('Cached for everyone'),
          ]),
        ]),
      ),
      // Daily AI chat allowance
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderLight, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(width: 32, height: 32, alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.base, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight, width: 1)),
            child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accent)),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ask AI inline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
              color: AppColors.textPrimary, fontFamily: 'Inter')),
            Text('30 free questions per day, resets at midnight UTC',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                color: AppColors.textMuted, fontFamily: 'Inter')),
          ])),
        ]),
      ),
      const SizedBox(height: 8),
      // AI features toggles
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderLight, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          _SectionSubLabel('AI FEATURES'),
          _ToggleRow('Article enrichment', '60-word summary + why it matters', _aiEnrichment, (v) => setState(() => _aiEnrichment = v)),
          const Divider(height: 0, indent: 16, endIndent: 16),
          _ToggleRow('Ask AI inline', 'Chat about any article', _aiInline, (v) => setState(() => _aiInline = v)),
          const Divider(height: 0, indent: 16, endIndent: 16),
          _ToggleRow('AI brief generation', 'Fill gaps when RSS is sparse', _aiBriefs, (v) => setState(() => _aiBriefs = v)),
          const Divider(height: 0, indent: 16, endIndent: 16),
          _ToggleRow('Weekly digest', 'Sunday intelligence summary', _aiWeekly, (v) => setState(() => _aiWeekly = v)),
        ]),
      ),
    ]);
  }

  Widget _buildNotifications() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        _ToggleRow('Morning dose ☀️', '${_profile.morningHour}:00 AM — daily read ready', _notifyMorning, (v) => setState(() => _notifyMorning = v)),
        const Divider(height: 0, indent: 16, endIndent: 16),
        _ToggleRow('Evening dose 🌙', '${_profile.eveningHour}:00 PM — wind down read', _notifyEvening, (v) => setState(() => _notifyEvening = v)),
        const Divider(height: 0, indent: 16, endIndent: 16),
        _ToggleRow('Streak at risk', 'Remind if not read by 9 PM', true, (_) {}),
        const Divider(height: 0, indent: 16, endIndent: 16),
        _ToggleRow('Review reminders', 'Vault articles due for review', true, (_) {}),
      ]),
    );
  }

  // ─── helpers ───────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
        color: AppColors.textPrimary, letterSpacing: .07, fontFamily: 'Inter')),
    );
  }

  Widget _divider() => Container(height: 30, width: 1, margin: const EdgeInsets.symmetric(horizontal: 12),
    color: AppColors.borderLight);

  String _previewForTopic(String topic) {
    const map = {
      'Payments': 'UPI Circle expansion — implications for family account products',
      'Regulation': 'RBI\'s new FLDG framework simplified for product teams',
      'Product': 'How to build a fintech PM portfolio that stands out in 2025',
      'AI & Tech': 'Gemini is now inside SBI YONO — what banks do next',
      'Startups': 'Slice–North East SFB merger — a new fintech-bank template',
      'Geopolitics': 'India–China trade reset: fintech cross-border implications',
      'Banking': 'CASA ratios under pressure — what digital banks are doing',
      'Macro / Finance': 'Dollar weakening: what it means for Indian fintech exports',
      'Cybersecurity': 'UPI fraud up 40% — the product responses that actually work',
      'Strategy': 'How CRED built ₹600 Cr on customers nobody else wanted',
      'Career / PM': 'Fintech PM salaries 2025 — what the top 10% earn',
      'Crypto / Web3': 'RBI\'s CBDC pilot: 1M users, lessons learned',
      'Insurtech': 'IRDAI\'s sandbox results — 3 startups that passed',
      'Wealthtech': 'Zerodha vs Groww — product thinking breakdown',
    };
    return map[topic] ?? '$topic insights and analysis for Indian fintech professionals';
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text;
  final Color bg, fg, border;
  const _Badge(this.text, this.bg, this.fg, this.border);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: 1),
      borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
      color: fg, fontFamily: 'Inter')));
}

class _StatCell extends StatelessWidget {
  final String num, label;
  const _StatCell(this.num, this.label);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: AppColors.surface,
      border: Border.all(color: AppColors.borderLight, width: 1.5), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(num, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
        color: AppColors.textPrimary, letterSpacing: -.5, fontFamily: 'Inter')),
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
        color: AppColors.textMuted, letterSpacing: .05, fontFamily: 'Inter')),
    ])));
}

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label, hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const _FieldRow({required this.icon, required this.label, required this.controller,
    required this.hint, this.keyboardType});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.textMuted),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textMuted, fontFamily: 'Inter')),
        const SizedBox(height: 3),
        TextField(controller: controller, keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary, fontFamily: 'Inter'),
          decoration: InputDecoration(hintText: hint, border: InputBorder.none,
            contentPadding: EdgeInsets.zero, isDense: true,
            hintStyle: const TextStyle(color: Color(0xFFB0ACA4), fontSize: 13, fontFamily: 'Inter'))),
      ])),
    ]));
}

class _ToggleRow extends StatelessWidget {
  final String label, sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(this.label, this.sub, this.value, this.onChanged);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary, fontFamily: 'Inter')),
        Text(sub, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
          color: AppColors.textMuted, fontFamily: 'Inter')),
      ])),
      Switch(value: value, onChanged: onChanged,
        activeColor: AppColors.success, activeTrackColor: AppColors.successLight,
        inactiveThumbColor: Colors.white, inactiveTrackColor: AppColors.borderLight),
    ]));
}

class _SectionSubLabel extends StatelessWidget {
  final String text;
  const _SectionSubLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 11, 14, 4),
    child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
      color: AppColors.textMuted, letterSpacing: .07, fontFamily: 'Inter')));
}


Widget _flowStep(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(5)),
  child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
    color: Colors.white, fontFamily: 'Inter')));

Widget _flowArr([String text = '\u2192']) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 2),
  child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
    color: Color(0xFF5A9A7A), fontFamily: 'Inter')));
