import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/article_repository.dart';
import '../utils/theme.dart';
import '../widgets/article_card.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final _repo = ArticleRepository.instance;
  final _searchCtrl = TextEditingController();
  List<Article> _all = [], _filtered = [], _reviewDue = [];

  @override
  void initState() { super.initState(); _reload(); _searchCtrl.addListener(_onSearch); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _all = _repo.getSavedArticles();
      _filtered = _all;
      _reviewDue = _repo.getReviewDueArticles();
    });
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim();
    setState(() => _filtered = q.isEmpty ? _all : _repo.searchVault(q));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHero()),
            SliverToBoxAdapter(child: _buildSearch()),
            if (_reviewDue.isNotEmpty && _searchCtrl.text.isEmpty) ...[
              SliverToBoxAdapter(child: _sectionLabel('REVIEW NOW', '${_reviewDue.length} due')),
              SliverList.builder(itemCount: _reviewDue.length, itemBuilder: (_, i) => ArticleCard(
                article: _reviewDue[i], showReviewBadge: true,
                onRead: () async { await _repo.markReviewed(_reviewDue[i].id); _reload(); },
                onSave: () async { await _repo.toggleSave(_reviewDue[i].id); _reload(); },
              )),
            ],
            SliverToBoxAdapter(child: _sectionLabel(
              _searchCtrl.text.isEmpty ? 'RECENTLY SAVED' : 'RESULTS', null)),
            if (_filtered.isEmpty)
              SliverToBoxAdapter(child: _buildEmpty())
            else
              SliverList.builder(itemCount: _filtered.length, itemBuilder: (_, i) => ArticleCard(
                article: _filtered[i],
                onRead: () async { await _repo.markRead(_filtered[i].id); _reload(); },
                onSave: () async { await _repo.toggleSave(_filtered[i].id); _reload(); },
              )),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_all.length}', style: const TextStyle(fontSize: 68, fontWeight: FontWeight.w900,
          color: AppColors.textPrimary, letterSpacing: -4, fontFamily: 'Inter', height: 1)),
        const SizedBox(height: 2),
        const Text('pieces in your brain vault',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: AppColors.textMuted, fontFamily: 'Inter')),
        const SizedBox(height: 13),
        const Divider(color: AppColors.borderLight, thickness: 1.5, height: 0),
      ]),
    );
  }

  Widget _buildSearch() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Padding(padding: EdgeInsets.only(left: 12), child: Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted)),
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary, fontFamily: 'Inter'),
            decoration: const InputDecoration(
              hintText: 'Search your intelligence...',
              hintStyle: TextStyle(color: Color(0xFFB0ACA4), fontFamily: 'Inter'),
              border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String text, String? right) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
          color: AppColors.textPrimary, letterSpacing: .07, fontFamily: 'Inter')),
        if (right != null)
          Text(right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: AppColors.accent, fontFamily: 'Inter')),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(children: [
        Text(_searchCtrl.text.isEmpty ? '🧠' : '🔍', style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(
          _searchCtrl.text.isEmpty
            ? 'Save articles from your feed\nto build your Fintech Vault!'
            : 'No results found',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, height: 1.5, fontFamily: 'Inter')),
      ]),
    );
  }
}
