import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import '../models/user_stats.dart';
import '../models/user_profile.dart';
import 'rss_service.dart';
import 'ai_service.dart';
import 'supabase_service.dart';

/// ════════════════════════════════════════════════════════════════════════
/// ArticleRepository — single source of truth for feed, vault, stats.
///
/// Architecture:
///   • RSS fetched client-side (rss_service.dart) — no backend cost.
///   • AI enrichment + briefs go through Supabase Edge Functions which
///     call NVIDIA NIM and cache results in `articles_cache` — shared
///     across ALL users, so identical articles cost AI tokens only once.
///   • Profile, stats, and vault (saved/read state) sync to Supabase
///     Postgres (per-user, RLS-protected) with a local Hive/SharedPrefs
///     cache for instant reads and offline support.
/// ════════════════════════════════════════════════════════════════════════
class ArticleRepository {
  ArticleRepository._();
  static final instance = ArticleRepository._();

  static const _boxName     = 'articles_v2';
  static const _prefStats   = 'user_stats_v3';
  static const _prefProfile = 'user_profile_v2';
  static const _prefFetch   = 'last_fetch_date';
  static const _prefIds     = 'today_article_ids';

  final _rss  = RssService();
  final _ai   = AiService();
  final _supa = SupabaseService.instance;

  late Box<Article> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Article>(_boxName);
  }

  bool get _online => _supa.isSignedIn;

  // ─── Profile ───────────────────────────────────────────────────────────

  /// Loads profile from Supabase if signed in (and caches locally),
  /// otherwise falls back to the local cache.
  Future<UserProfile> getProfile() async {
    if (_online) {
      try {
        final row = await _supa.client
            .from('profiles')
            .select()
            .eq('id', _supa.currentUser!.id)
            .maybeSingle();
        if (row != null) {
          final profile = UserProfile(
            name: row['name'] ?? '',
            email: row['email'] ?? '',
            role: row['role'] ?? '',
            location: row['location'] ?? '',
            careerGoal: row['career_goal'] ?? '',
            interests: List<String>.from(row['interests'] ?? UserProfile.defaultInterests),
            notifyMorning: row['notify_morning'] ?? true,
            notifyEvening: row['notify_evening'] ?? true,
            morningHour: row['morning_hour'] ?? 8,
            eveningHour: row['evening_hour'] ?? 21,
            aiEnrichment: row['ai_enrichment'] ?? true,
            aiInline: row['ai_inline'] ?? true,
            aiBriefs: row['ai_briefs'] ?? true,
            aiWeeklyDigest: row['ai_weekly_digest'] ?? true,
          );
          await _cacheProfile(profile);
          return profile;
        }
      } catch (_) {}
    }
    return _localProfile();
  }

  Future<UserProfile> _localProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefProfile);
    if (raw == null || raw.isEmpty) return const UserProfile();
    try { return UserProfile.fromJsonString(raw); } catch (_) { return const UserProfile(); }
  }

  Future<void> _cacheProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefProfile, profile.toJsonString());
  }

  /// Saves profile to Supabase (if signed in) AND the local cache.
  Future<void> saveProfile(UserProfile profile) async {
    await _cacheProfile(profile);
    if (!_online) return;
    try {
      await _supa.client.from('profiles').upsert({
        'id': _supa.currentUser!.id,
        'name': profile.name,
        'email': profile.email,
        'role': profile.role,
        'location': profile.location,
        'career_goal': profile.careerGoal,
        'interests': profile.interests,
        'notify_morning': profile.notifyMorning,
        'notify_evening': profile.notifyEvening,
        'morning_hour': profile.morningHour,
        'evening_hour': profile.eveningHour,
        'ai_enrichment': profile.aiEnrichment,
        'ai_inline': profile.aiInline,
        'ai_briefs': profile.aiBriefs,
        'ai_weekly_digest': profile.aiWeeklyDigest,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // ─── Feed ──────────────────────────────────────────────────────────────
  Future<List<Article>> getTodayFeed({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (!forceRefresh && prefs.getString(_prefFetch) == today) {
      final ids = prefs.getStringList(_prefIds) ?? [];
      final cached = ids.map((id) => _box.get(id)).whereType<Article>().toList();
      if (cached.isNotEmpty) return cached;
    }

    final articles = await _buildFeed();
    await prefs.setString(_prefFetch, today);
    await prefs.setStringList(_prefIds, articles.map((a) => a.id).toList());
    return articles;
  }

  Future<List<Article>> _buildFeed() async {
    final profile = await getProfile();
    final stats   = await getStats();
    final history = stats.topicCounts.keys.toList();
    final interests = profile.interests.isEmpty ? UserProfile.defaultInterests : profile.interests;

    // 1. RSS fetch filtered by interests (no backend cost)
    final rssItems = await _rss.fetchAll(interests: interests);

    // 2. Pick one per type ensuring variety
    final picked = <_RawItem>[];
    final usedTypes = <ArticleType>{};
    for (final item in rssItems) {
      if (!usedTypes.contains(item.type) && picked.length < 4) {
        picked.add(_RawItem.fromRss(item));
        usedTypes.add(item.type);
      }
    }

    // 3. Fill gaps with shared AI briefs (cached per date+interest-set)
    final needed = (4 - picked.length).clamp(0, 4);
    if (needed > 0 && profile.aiBriefs) {
      final briefs = await _ai.generateBriefs(
        coveredTopics: history, interests: interests, count: needed,
      );
      for (final b in briefs) picked.add(_RawItem.fromBrief(b));
    }

    // 4. Enrich each via the shared cache — first user to see an article
    //    pays the AI cost, every subsequent user gets a free cache hit.
    final articles = <Article>[];
    for (final item in picked.take(4)) {
      String summary      = item.prefilledSummary ?? '';
      String whyItMatters = item.prefilledWhy     ?? '';

      if (profile.aiEnrichment && (summary.isEmpty || whyItMatters.isEmpty)) {
        final enriched = await _ai.enrichArticle(
          id: item.id, title: item.title, url: item.url,
          rawContent: item.rawContent, source: item.source,
          topic: item.topic, type: item.type.name,
          estimatedMinutes: item.estimatedMinutes,
          userHistory: history.join(', '),
        );
        if (enriched.summary.isNotEmpty)      summary      = enriched.summary;
        if (enriched.whyItMatters.isNotEmpty) whyItMatters = enriched.whyItMatters;
      }

      // Fallback so cards never look empty when AI is off / offline
      if (summary.isEmpty) {
        summary = item.rawContent.isNotEmpty
            ? (item.rawContent.length > 280 ? '${item.rawContent.substring(0, 280)}...' : item.rawContent)
            : 'Tap "Read full" to view this article on ${item.source}.';
      }
      if (whyItMatters.isEmpty) {
        whyItMatters = 'Relevant to your interest in ${item.topic}.';
      }

      final article = Article(
        id: item.id, title: item.title, url: item.url,
        summary: summary, whyItMatters: whyItMatters,
        source: item.source, type: item.type,
        publishedAt: item.publishedAt, topic: item.topic,
        estimatedMinutes: item.estimatedMinutes,
      );
      await _box.put(article.id, article);
      articles.add(article);

      // Track that this user has been shown this article (for review sync)
      unawaited(_syncUserArticle(article.id, shown: true));
    }
    return articles;
  }

  // ─── Vault ─────────────────────────────────────────────────────────────
  List<Article> getSavedArticles() => _box.values.where((a) => a.isSaved).toList()
    ..sort((a, b) => (b.savedAt ?? b.publishedAt).compareTo(a.savedAt ?? a.publishedAt));

  List<Article> getReviewDueArticles() => getSavedArticles().where((a) => a.needsReview).toList();

  List<Article> searchVault(String query) {
    final q = query.toLowerCase();
    return _box.values.where((a) => a.isSaved && (
      a.title.toLowerCase().contains(q) ||
      a.topic.toLowerCase().contains(q) ||
      a.source.toLowerCase().contains(q)
    )).toList();
  }

  // ─── Mutations ─────────────────────────────────────────────────────────
  Future<void> markRead(String id) async {
    final a = _box.get(id);
    if (a == null || a.isRead) return;
    a.isRead = true; await a.save();
    await _incrementReadStats(a.topic);
    unawaited(_syncUserArticle(id, isRead: true));
  }

  Future<void> toggleSave(String id) async {
    final a = _box.get(id);
    if (a == null) return;
    a.isSaved = !a.isSaved;
    a.savedAt = a.isSaved ? DateTime.now() : null;
    await a.save();
    await _updateSavedDelta(a.isSaved ? 1 : -1);
    unawaited(_syncUserArticle(id, isSaved: a.isSaved, savedAt: a.savedAt));
  }

  Future<void> markReviewed(String id) async {
    final a = _box.get(id);
    if (a == null) return;
    a.lastReviewedAt = DateTime.now(); await a.save();
    unawaited(_syncUserArticle(id, lastReviewedAt: a.lastReviewedAt));
  }

  /// Upserts the per-user article state row in Supabase. Fire-and-forget —
  /// local Hive is always the source of truth for the UI.
  Future<void> _syncUserArticle(String articleId, {
    bool? isRead, bool? isSaved, DateTime? savedAt, DateTime? lastReviewedAt, bool shown = false,
  }) async {
    if (!_online) return;
    try {
      final row = <String, dynamic>{
        'user_id': _supa.currentUser!.id,
        'article_id': articleId,
      };
      if (isRead != null) row['is_read'] = isRead;
      if (isSaved != null) row['is_saved'] = isSaved;
      if (savedAt != null || isSaved == false) row['saved_at'] = savedAt?.toIso8601String();
      if (lastReviewedAt != null) row['last_reviewed_at'] = lastReviewedAt.toIso8601String();
      if (shown) row['shown_at'] = DateTime.now().toIso8601String();
      await _supa.client.from('user_articles').upsert(row, onConflict: 'user_id,article_id');
    } catch (_) {}
  }

  // ─── Stats ─────────────────────────────────────────────────────────────

  /// Loads stats from Supabase if signed in (and caches locally),
  /// otherwise falls back to the local cache.
  Future<UserStats> getStats() async {
    if (_online) {
      try {
        final row = await _supa.client
            .from('user_stats')
            .select()
            .eq('user_id', _supa.currentUser!.id)
            .maybeSingle();
        if (row != null) {
          final stats = UserStats(
            streak: row['streak'] ?? 0,
            totalRead: row['total_read'] ?? 0,
            totalSaved: row['total_saved'] ?? 0,
            lastReadDate: row['last_read_date'] != null ? DateTime.tryParse(row['last_read_date']) : null,
            topicCounts: Map<String, int>.from(row['topic_counts'] ?? {}),
          );
          await _cacheStats(stats);
          return stats;
        }
      } catch (_) {}
    }
    return _localStats();
  }

  Future<UserStats> _localStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefStats);
    if (raw == null || raw.isEmpty) return const UserStats();
    try { return UserStats.fromJsonString(raw); } catch (_) { return const UserStats(); }
  }

  Future<void> _cacheStats(UserStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefStats, stats.toJsonString());
  }

  Future<void> _saveStats(UserStats stats) async {
    await _cacheStats(stats);
    if (!_online) return;
    try {
      await _supa.client.from('user_stats').upsert({
        'user_id': _supa.currentUser!.id,
        'streak': stats.streak,
        'total_read': stats.totalRead,
        'total_saved': stats.totalSaved,
        'last_read_date': stats.lastReadDate?.toIso8601String().substring(0, 10),
        'topic_counts': stats.topicCounts,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> _incrementReadStats(String topic) async {
    var s = await getStats();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastStr  = s.lastReadDate != null ? DateFormat('yyyy-MM-dd').format(s.lastReadDate!) : '';
    final yestStr  = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
    final newStreak = lastStr == todayStr ? s.streak : lastStr == yestStr ? s.streak + 1 : 1;
    final counts = Map<String, int>.from(s.topicCounts)..[topic] = (s.topicCounts[topic] ?? 0) + 1;
    s = s.copyWith(streak: newStreak, totalRead: s.totalRead + 1, lastReadDate: DateTime.now(), topicCounts: counts);
    await _saveStats(s);
  }

  Future<void> _updateSavedDelta(int delta) async {
    var s = await getStats();
    s = s.copyWith(totalSaved: (s.totalSaved + delta).clamp(0, 99999));
    await _saveStats(s);
  }
}

/// Fire-and-forget helper — runs a future without making the caller await it.
void unawaited(Future<void> future) {
  future.catchError((_) {});
}

class _RawItem {
  final String id, title, url, rawContent, source, topic;
  final ArticleType type;
  final DateTime publishedAt;
  final int estimatedMinutes;
  final String? prefilledSummary, prefilledWhy;

  const _RawItem({required this.id, required this.title, required this.url,
    required this.rawContent, required this.source, required this.type,
    required this.topic, required this.publishedAt, required this.estimatedMinutes,
    this.prefilledSummary, this.prefilledWhy});

  factory _RawItem.fromRss(RssItem r) => _RawItem(
    id: AiService.articleId(r.title, r.url),
    title: r.title, url: r.url, rawContent: r.rawContent,
    source: r.source, type: r.type, topic: r.topic,
    publishedAt: r.publishedAt, estimatedMinutes: r.estimatedMinutes);

  factory _RawItem.fromBrief(Map<String, dynamic> b) {
    ArticleType type;
    try {
      type = ArticleType.values.firstWhere((t) => t.name == b['type'], orElse: () => ArticleType.news);
    } catch (_) { type = ArticleType.news; }
    final title = (b['title'] as String?) ?? 'Fintech update';
    final url = (b['url'] as String?) ?? 'https://rbi.org.in';
    // Backend already assigned a stable cache id for this brief (per date +
    // interest-set). Fall back to a deterministic hash if missing.
    final id = (b['id'] as String?) ?? AiService.articleId(title, url);
    return _RawItem(
      id: id,
      title: title,
      url: url,
      rawContent: (b['summary'] as String?) ?? '',
      source: (b['source'] as String?) ?? 'AI Brief',
      type: type,
      topic: (b['topic'] as String?) ?? 'General',
      publishedAt: DateTime.now(),
      estimatedMinutes: (b['estimatedMinutes'] as int?) ?? 5,
      prefilledSummary: b['summary'] as String?,
      prefilledWhy: b['whyItMatters'] as String?,
    );
  }
}
