import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'supabase_service.dart';

/// ════════════════════════════════════════════════════════════════════════
/// AiService — talks to Supabase Edge Functions, which call NVIDIA NIM.
///
/// No API keys live on-device anymore. Every AI call goes through the
/// backend's shared cache (enrich-article), per-user chat (ai-chat), or
/// shared daily briefs (generate-briefs).
/// ════════════════════════════════════════════════════════════════════════
class AiService {
  final _supa = SupabaseService.instance;

  /// Deterministic cache key shared by every user for the same article.
  static String articleId(String title, String url) {
    final bytes = utf8.encode('$title|$url');
    return sha256.convert(bytes).toString();
  }

  /// Returns a 60-word summary + "why it matters". Backend caches the
  /// result per article — only the FIRST user to see an article pays
  /// the AI cost.
  Future<({String summary, String whyItMatters, bool cached})> enrichArticle({
    required String id,
    required String title,
    required String url,
    required String rawContent,
    required String source,
    required String topic,
    required String type,
    required int estimatedMinutes,
    required String userHistory,
  }) async {
    try {
      final res = await _supa.invoke('enrich-article', {
        'id': id,
        'title': title,
        'url': url,
        'rawContent': rawContent,
        'source': source,
        'topic': topic,
        'type': type,
        'estimatedMinutes': estimatedMinutes,
        'userHistory': userHistory,
      });
      return (
        summary: (res['summary'] as String?) ?? '',
        whyItMatters: (res['whyItMatters'] as String?) ?? '',
        cached: (res['cached'] as bool?) ?? false,
      );
    } catch (_) {
      return (
        summary: '$title — tap "Read full" to view this article on $source.',
        whyItMatters: 'Relevant to your interest in $topic.',
        cached: false,
      );
    }
  }

  /// AI-generated filler articles when RSS is sparse. Cached per
  /// (date + interest-set) so users with similar profiles share results.
  Future<List<Map<String, dynamic>>> generateBriefs({
    required List<String> coveredTopics,
    required List<String> interests,
    int count = 2,
  }) async {
    try {
      final res = await _supa.invoke('generate-briefs', {
        'interests': interests,
        'coveredTopics': coveredTopics,
        'count': count,
      });
      return List<Map<String, dynamic>>.from(res['briefs'] as List? ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Inline "Ask AI about this article" — per-user, NOT cached.
  /// Rate-limited server-side (default 30/day) to protect the free tier.
  Future<({String answer, bool limited, int? remaining})> askAboutArticle({
    required String articleId,
    required String articleTitle,
    required String articleSummary,
    required String question,
    required List<Map<String, String>> history,
  }) async {
    try {
      final res = await _supa.invoke('ai-chat', {
        'articleId': articleId,
        'articleTitle': articleTitle,
        'articleSummary': articleSummary,
        'question': question,
        'history': history,
      });
      return (
        answer: (res['answer'] as String?) ?? '',
        limited: (res['limited'] as bool?) ?? false,
        remaining: res['remaining'] as int?,
      );
    } catch (e) {
      return (
        answer: 'Could not reach the AI right now. Please check your connection and try again.',
        limited: false,
        remaining: null,
      );
    }
  }
}
