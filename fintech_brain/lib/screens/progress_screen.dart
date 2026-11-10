import 'package:flutter/material.dart';
import '../models/user_stats.dart';
import '../services/article_repository.dart';
import '../utils/theme.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _repo = ArticleRepository.instance;
  UserStats _stats = const UserStats();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final s = await _repo.getStats();
    if (!mounted) return;
    setState(() => _stats = s);
  }

  @override
  Widget build(BuildContext context) {
    final monthsIn = (_stats.totalRead / 27.3).ceil().clamp(1, 11);
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.accent,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHero(monthsIn)),
              SliverToBoxAdapter(child: _buildStatGrid()),
              SliverToBoxAdapter(child: _buildProgressBar()),
              SliverToBoxAdapter(child: _buildTopicBars()),
              SliverToBoxAdapter(child: _buildIdentityCard()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(int monthsIn) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_stats.totalRead}',
          style: const TextStyle(fontSize: 68, fontWeight: FontWeight.w900,
            color: AppColors.textPrimary, letterSpacing: -4, fontFamily: 'Inter', height: 1)),
        Text('pieces read · Month $monthsIn of 11',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: AppColors.textMuted, fontFamily: 'Inter')),
        const SizedBox(height: 13),
        const Divider(color: AppColors.borderLight, thickness: 1.5, height: 0),
      ]),
    );
  }

  Widget _buildStatGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(children: [
        Expanded(child: _StatBox(num: '${_stats.streak}', label: 'Day streak',
          delta: '+1 today 🔥', bg: AppColors.accent, numColor: Colors.white,
          labelColor: Colors.white.withOpacity(.6), deltaColor: Colors.white.withOpacity(.8))),
        const SizedBox(width: 8),
        Expanded(child: _StatBox(num: '${_stats.totalSaved}', label: 'Saved',
          delta: 'in vault', bg: AppColors.nearBlack, numColor: Colors.white,
          labelColor: Colors.white.withOpacity(.55), deltaColor: Colors.white.withOpacity(.7))),
        const SizedBox(width: 8),
        Expanded(child: _StatBox(num: '${(_stats.progressPercent * 100).round()}%', label: 'To goal',
          delta: 'on track ✓', bg: AppColors.surface,
          border: Border.all(color: AppColors.borderLight, width: 1.5),
          numColor: AppColors.textPrimary, labelColor: AppColors.textMuted,
          deltaColor: AppColors.success)),
        const SizedBox(width: 8),
        Expanded(child: _StatBox(num: '${UserStats.goalTotal - _stats.totalRead}', label: 'Remaining',
          delta: '11 months', bg: AppColors.surface,
          border: Border.all(color: AppColors.borderLight, width: 1.5),
          numColor: AppColors.textPrimary, labelColor: AppColors.textMuted,
          deltaColor: AppColors.textMuted)),
      ]),
    );
  }

  Widget _buildProgressBar() {
    final pct = _stats.progressPercent;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 9, 20, 0),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.nearBlack,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Journey to 300',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.base, fontFamily: 'Inter')),
          Text('${(pct * 100).round()}%',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
              color: AppColors.accent, letterSpacing: -1, fontFamily: 'Inter')),
        ]),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct, minHeight: 5,
            backgroundColor: const Color(0xFF2E2E2C),
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        const SizedBox(height: 5),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${_stats.totalRead} read',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: Color(0xFF5A5A58), fontFamily: 'Inter')),
          const Text('300 goal',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: Color(0xFF5A5A58), fontFamily: 'Inter')),
        ]),
      ]),
    );
  }

  Widget _buildTopicBars() {
    final topics = [
      ('Payments', AppColors.accent),
      ('Regulation', AppColors.regulation),
      ('Product', AppColors.product),
      ('Geopolitics', AppColors.geopolitics),
      ('AI & Tech', AppColors.aiTech),
      ('Startups', AppColors.startups),
    ];
    final maxCount = _stats.topicCounts.values.fold(1, (m, v) => v > m ? v : m);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 9, 20, 0),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TOPICS MASTERED',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary, letterSpacing: .07, fontFamily: 'Inter')),
        const SizedBox(height: 13),
        ...topics.map((t) {
          final count = _stats.topicCounts[t.$1] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(children: [
              SizedBox(width: 82, child: Text(t.$1,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, fontFamily: 'Inter'))),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: maxCount > 0 ? count / maxCount : 0,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFEAE7E0),
                  valueColor: AlwaysStoppedAnimation(t.$2),
                ),
              )),
              const SizedBox(width: 8),
              SizedBox(width: 20, child: Text('$count',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, fontFamily: 'Inter'))),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildIdentityCard() {
    const milestones = [7, 14, 30, 60, 100, 200, 300, 365];
    final next = milestones.firstWhere((m) => m > _stats.streak, orElse: () => 365);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 9, 20, 0),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.accent,
        border: Border.all(color: AppColors.accentDark, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('THIS WEEK YOU ARE',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
            color: Color(0x99FFFFFF), letterSpacing: .08, fontFamily: 'Inter')),
        const SizedBox(height: 5),
        Text(
          _stats.totalRead > 0
            ? 'The person building fintech mastery — ${_stats.topPercentile} of professionals'
            : 'Start reading to build your identity',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
            color: Colors.white, height: 1.35, fontFamily: 'Inter')),
        const SizedBox(height: 7),
        Text(
          _stats.streak == 0
            ? 'Read today to start your streak!'
            : '${next - _stats.streak} more days to hit $next-day milestone 🔥',
          style: const TextStyle(fontSize: 12, color: Color(0xCCFFFFFF),
            height: 1.5, fontFamily: 'Inter')),
        if (_stats.topicCounts.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 5, runSpacing: 5,
            children: _stats.topicCounts.entries.take(5).map((e) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.17),
                  borderRadius: BorderRadius.circular(5)),
                child: Text(e.key,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.white, fontFamily: 'Inter')),
              )
            ).toList()),
        ],
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String num, label, delta;
  final Color bg, numColor, labelColor, deltaColor;
  final Border? border;
  const _StatBox({required this.num, required this.label, required this.delta,
    required this.bg, required this.numColor, required this.labelColor,
    required this.deltaColor, this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, border: border, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(num, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
          color: numColor, letterSpacing: -1, fontFamily: 'Inter', height: 1)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
          color: labelColor, letterSpacing: .06, fontFamily: 'Inter',
          textBaseline: TextBaseline.alphabetic)),
        const SizedBox(height: 5),
        Text(delta, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: deltaColor, fontFamily: 'Inter')),
      ]),
    );
  }
}
