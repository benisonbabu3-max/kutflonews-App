import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/article.dart';
import '../services/article_repository.dart';
import '../utils/theme.dart';
import '../widgets/article_card.dart';
import '../widgets/app_button.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _repo = ArticleRepository.instance;
  List<Article> _articles = [];
  bool _loading = true;
  String _filter = 'All';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final a = await _repo.getTodayFeed();
      if (!mounted) return;
      setState(() { _articles = a; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _markRead(Article a) async {
    await _repo.markRead(a.id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleSave(Article a) async {
    await _repo.toggleSave(a.id);
    if (!mounted) return;
    setState(() {});
  }

  List<Article> get _filtered {
    if (_filter == 'All') return _articles;
    return _articles.where((a) => a.topic.toLowerCase().contains(_filter.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(
            child: _loading ? _buildShimmer() : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.accent,
              child: _filtered.isEmpty
                ? const Center(child: Text('No articles found', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Inter')))
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 100),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => ArticleCard(
                      article: _filtered[i],
                      onRead: () => _markRead(_filtered[i]),
                      onSave: () => _toggleSave(_filtered[i]),
                    ),
                  ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Today's signals",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                color: AppColors.textPrimary, letterSpacing: -.4, fontFamily: 'Inter')),
            Text('${_articles.length} articles · ${_articles.fold(0, (s, a) => s + a.estimatedMinutes)} min total',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: AppColors.textMuted, fontFamily: 'Inter')),
          ]),
          PrimaryButton(label: 'Filter', small: true, onTap: _showFilterSheet),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final topics = ['All', 'Regulation', 'Payments', 'Product', 'Geopolitics', 'AI & Tech'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        itemCount: topics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) => PillButton(
          label: topics[i], selected: _filter == topics[i],
          onTap: () => setState(() => _filter = topics[i]),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0DDD8), highlightColor: const Color(0xFFF0EDE8),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          height: 200, margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18))),
      ),
    );
  }

  void _showFilterSheet() {
    // simple filter — handled by pill row
  }
}
