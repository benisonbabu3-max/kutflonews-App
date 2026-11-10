import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/article.dart';
import '../models/user_stats.dart';
import '../services/article_repository.dart';
import '../services/notification_service.dart';
import '../utils/theme.dart';
import '../widgets/app_button.dart';
import '../widgets/swipe_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = ArticleRepository.instance;
  List<Article> _articles = [];
  UserStats _stats = const UserStats();
  String _userName = 'there';
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'All';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final profile  = await _repo.getProfile();
      final articles = await _repo.getTodayFeed(forceRefresh: forceRefresh);
      final stats    = await _repo.getStats();
      if (!mounted) return;
      setState(() {
        _articles  = articles;
        _stats     = stats;
        _userName  = profile.name.split(' ').first;
        _loading   = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _onSwiped(Article article, bool saved) async {
    if (saved) {
      await _repo.toggleSave(article.id);
      _showToast('Saved to vault 🔖');
    } else {
      _showToast('Skipped');
    }
    await _repo.markRead(article.id);
    final stats = await _repo.getStats();
    if (stats.streak > 0 && stats.streak % 7 == 0) {
      await NotificationService.showStreakCelebration(stats.streak);
    }
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.nearBlack,
      duration: const Duration(seconds: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    ));
  }

  List<Article> get _filteredArticles {
    if (_selectedFilter == 'All') return _articles;
    return _articles.where((a) => a.topic.toLowerCase().contains(_selectedFilter.toLowerCase())).toList();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: RefreshIndicator(
        onRefresh: () => _load(forceRefresh: true),
        color: AppColors.accent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildFilters()),
            if (_loading)
              SliverToBoxAdapter(child: _buildShimmer())
            else if (_error != null)
              SliverToBoxAdapter(child: _buildError())
            else ...[
              SliverToBoxAdapter(child: _buildSwipeSection()),
              SliverToBoxAdapter(child: _buildRefreshRow()),
              SliverToBoxAdapter(child: _buildStreak()),
              SliverToBoxAdapter(child: _buildGrid()),
              SliverToBoxAdapter(child: _buildIntelCard()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${_dayLabel()} · ${_dateLabel()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textMuted, letterSpacing: .07, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 4),
              Text(_greeting, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900,
                color: AppColors.textPrimary, letterSpacing: -.4, fontFamily: 'Inter', height: 1.1)),
              Text('$_userName.', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900,
                color: AppColors.textPrimary, letterSpacing: -.4, fontFamily: 'Inter', height: 1.1)),
            ]),
          ),
          const SizedBox(width: 12),
          // Avatar
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/profile'),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.nearBlack, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: Colors.white, fontFamily: 'Inter')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final topics = ['All', 'Payments', 'Regulation', 'Geopolitics', 'AI & Tech', 'Startups', 'Product'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        itemCount: topics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) => PillButton(
          label: topics[i],
          selected: _selectedFilter == topics[i],
          onTap: () => setState(() => _selectedFilter = topics[i]),
        ),
      ),
    );
  }

  Widget _buildSwipeSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: SwipeCardStack(
        articles: _filteredArticles,
        onRefresh: () => _load(forceRefresh: true),
        onSwiped: _onSwiped,
      ),
    );
  }

  Widget _buildRefreshRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${_articles.length} signals today',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.textSecondary, fontFamily: 'Inter')),
          GestureDetector(
            onTap: () => _load(forceRefresh: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 1.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.refresh_rounded, size: 13, color: AppColors.accent),
                const SizedBox(width: 4),
                const Text('Refresh feed',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: AppColors.accent, fontFamily: 'Inter')),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreak() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/progress'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.nearBlack,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Text('${_stats.streak}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
              color: AppColors.base, letterSpacing: -1.5, fontFamily: 'Inter')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DAY STREAK',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                  color: Color(0xFF6A6866), letterSpacing: .07, fontFamily: 'Inter')),
              Text('${_stats.totalRead} read · ${UserStats.goalTotal - _stats.totalRead} to goal',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.base, fontFamily: 'Inter')),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: List.generate(7, (i) => Container(
              width: 7, height: 7, margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: i < (_stats.streak % 7 == 0 ? 7 : _stats.streak % 7)
                    ? AppColors.accent : const Color(0xFF2E2E2C),
                shape: BoxShape.circle),
            ))),
            const SizedBox(height: 5),
            const Text('🔥', style: TextStyle(fontSize: 16)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(children: [
        Expanded(child: _GridCard(
          bg: AppColors.nearBlack,
          tag: 'Geopolitics', tagBg: Colors.white.withOpacity(.1), tagText: Colors.white.withOpacity(.8),
          title: 'India–US trade: fintech implications',
          meta: '5 min · Reuters',
          titleColor: AppColors.base, metaColor: Colors.white.withOpacity(.5),
          ghost: '02', ghostColor: Colors.white,
          onTap: () => Navigator.of(context).pushNamed('/feed'),
        )),
        const SizedBox(width: 9),
        Expanded(child: Column(children: [
          _GridCard(
            bg: const Color(0xFFF0E8D8),
            borderColor: const Color(0xFFC8A878),
            tag: '21% goal', tagBg: Colors.black.withOpacity(.08), tagText: AppColors.nearBlack,
            title: 'View your progress',
            meta: 'Stats & streaks →',
            titleColor: AppColors.nearBlack, metaColor: AppColors.accent,
            ghost: '', ghostColor: Colors.black,
            onTap: () => Navigator.of(context).pushNamed('/progress'),
          ),
          const SizedBox(height: 9),
          _GridCard(
            bg: AppColors.accent,
            borderColor: AppColors.accentDark,
            tag: 'Vault', tagBg: Colors.black.withOpacity(.15), tagText: Colors.white,
            title: '${_getReviewCount()} due for review',
            meta: 'Review now →',
            titleColor: Colors.white, metaColor: Colors.white.withOpacity(.8),
            ghost: '${_stats.totalSaved}', ghostColor: Colors.white,
            onTap: () => Navigator.of(context).pushNamed('/vault'),
          ),
        ])),
      ]),
    );
  }

  int _getReviewCount() => _repo.getReviewDueArticles().length;

  Widget _buildIntelCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.accent,
        border: Border.all(color: AppColors.accentDark, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('THIS WEEK YOU ARE',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
            color: Color(0x99FFFFFF), letterSpacing: .08, fontFamily: 'Inter')),
        const SizedBox(height: 5),
        Text(
          _stats.totalRead > 10
            ? 'The person who knows more about fintech than ${_stats.topPercentile} of professionals'
            : 'Building your fintech domain knowledge — keep going!',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
            color: Colors.white, height: 1.35, letterSpacing: -.1, fontFamily: 'Inter')),
        const SizedBox(height: 7),
        Text(
          '${_stats.totalRead} pieces read this journey. ${UserStats.goalTotal - _stats.totalRead} more to reach your goal.',
          style: const TextStyle(fontSize: 12, color: Color(0xCCFFFFFF), height: 1.55, fontFamily: 'Inter')),
        if (_stats.topicCounts.isNotEmpty) ...[
          const SizedBox(height: 9),
          Wrap(spacing: 5, runSpacing: 5, children: _stats.topicCounts.entries.take(4).map((e) =>
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.black.withOpacity(.18), borderRadius: BorderRadius.circular(5)),
              child: Text(e.key, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Inter'))),
          ).toList()),
        ],
      ]),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0DDD8),
      highlightColor: const Color(0xFFF0EDE8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(height: 236, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 10),
          Container(height: 64, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 10),
          Container(height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
        ]),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        const Text('⚠️', style: TextStyle(fontSize: 36)),
        const SizedBox(height: 10),
        const Text('Could not load feed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'Inter')),
        const SizedBox(height: 4),
        Text(_error!, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'Inter')),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Try again', onTap: _load),
      ]),
    );
  }

  String _dayLabel() {
    const days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    return days[DateTime.now().weekday % 7];
  }

  String _dateLabel() {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final n = DateTime.now();
    return '${months[n.month - 1]} ${n.day}';
  }
}

class _GridCard extends StatelessWidget {
  final Color bg;
  final Color? borderColor;
  final String tag, title, meta, ghost;
  final Color tagBg, tagText, titleColor, metaColor, ghostColor;
  final VoidCallback? onTap;

  const _GridCard({
    required this.bg, this.borderColor, required this.tag, required this.title,
    required this.meta, required this.ghost, required this.tagBg, required this.tagText,
    required this.titleColor, required this.metaColor, required this.ghostColor, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor ?? bg, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(children: [
          // Ghost
          Positioned(bottom: 0, right: 4,
            child: Text(ghost, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900,
              color: ghostColor.withOpacity(.07), fontFamily: 'Inter', height: 1))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(5)),
              child: Text(tag, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                color: tagText, letterSpacing: .05, fontFamily: 'Inter'))),
            const SizedBox(height: 7),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
              color: titleColor, height: 1.3, letterSpacing: -.1, fontFamily: 'Inter'),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Text(meta, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: metaColor, fontFamily: 'Inter')),
            const SizedBox(height: 26),
          ]),
        ]),
      ),
    );
  }
}
