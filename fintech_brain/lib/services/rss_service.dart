import 'package:http/http.dart' as http;
import '../models/article.dart';

class RssService {
  static const _kTimeout = Duration(seconds: 10);

  static const _feeds = <_FeedCfg>[
    _FeedCfg('https://rbi.org.in/Scripts/Rss.aspx?Id=3', 'RBI.org.in', ArticleType.rbiCircular, 'Regulation'),
    _FeedCfg('https://entrackr.com/feed/', 'Entrackr', ArticleType.news, 'Startups'),
    _FeedCfg('https://inc42.com/feed/', 'Inc42', ArticleType.news, 'Startups'),
    _FeedCfg('https://yourstory.com/feed', 'YourStory', ArticleType.news, 'Startups'),
    _FeedCfg('https://thefintechtimes.com/feed/', 'Fintech Times', ArticleType.news, 'Payments'),
    _FeedCfg('https://medium.com/feed/tag/fintech', 'Medium', ArticleType.productBlog, 'Product'),
    _FeedCfg('https://medium.com/feed/tag/product-management', 'Medium PM', ArticleType.productBlog, 'Product'),
  ];

  Future<List<RssItem>> fetchAll({List<String> interests = const []}) async {
    final futures = _feeds.map(_fetchFeed);
    final results = await Future.wait(futures, eagerError: false);
    var items = results.expand((l) => l).toList();

    // Filter by interests if provided
    if (interests.isNotEmpty) {
      final lower = interests.map((i) => i.toLowerCase()).toList();
      items = items.where((item) =>
        lower.any((interest) =>
          item.topic.toLowerCase().contains(interest) ||
          item.title.toLowerCase().contains(interest)
        )
      ).toList();
    }

    items.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return items.take(30).toList();
  }

  Future<List<RssItem>> _fetchFeed(_FeedCfg cfg) async {
    try {
      final resp = await http.get(Uri.parse(cfg.url),
        headers: const {'User-Agent': 'FintechBrain/2.0 (flutter)'})
        .timeout(_kTimeout);
      if (resp.statusCode != 200) return [];
      return _parse(resp.body, cfg);
    } catch (_) { return []; }
  }

  List<RssItem> _parse(String body, _FeedCfg cfg) {
    final results = <RssItem>[];
    final itemRx = RegExp(r'<item\b[^>]*>([\s\S]*?)</item>', caseSensitive: false);
    for (final m in itemRx.allMatches(body).take(6)) {
      final block = m.group(1) ?? '';
      final title = _tag(block, 'title').trim();
      final link  = _tag(block, 'link').trim();
      if (title.isEmpty || link.isEmpty) continue;
      final desc = _stripHtml(_tag(block, 'description'));
      if (!_isRelevant('$title $desc')) continue;
      results.add(RssItem(
        id: link.hashCode.abs().toString(),
        title: title, url: link, rawContent: desc,
        source: cfg.source, type: cfg.type, topic: cfg.topic,
        publishedAt: _parseDate(_tag(block, 'pubDate')),
        estimatedMinutes: _readTime(desc),
      ));
    }
    return results;
  }

  String _tag(String xml, String tag) {
    final cd = RegExp('<$tag[^>]*>\\s*<!\\[CDATA\\[([\\s\\S]*?)\\]\\]>\\s*</$tag>', caseSensitive: false).firstMatch(xml);
    if (cd != null) return cd.group(1) ?? '';
    final pl = RegExp('<$tag[^>]*>([\\s\\S]*?)</$tag>', caseSensitive: false).firstMatch(xml);
    return pl?.group(1) ?? '';
  }

  String _stripHtml(String html) => html
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ').replaceAll('&#39;', "'").replaceAll('&quot;', '"')
    .replaceAll(RegExp(r'\s{2,}'), ' ').trim();

  DateTime _parseDate(String raw) {
    if (raw.isEmpty) return DateTime.now();
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;
    try {
      const months = {'jan':'01','feb':'02','mar':'03','apr':'04','may':'05','jun':'06',
        'jul':'07','aug':'08','sep':'09','oct':'10','nov':'11','dec':'12'};
      final parts = raw.trim().split(RegExp(r'\s+'));
      if (parts.length >= 5) {
        final day = parts[1].padLeft(2, '0');
        final month = months[parts[2].toLowerCase()] ?? '01';
        return DateTime.tryParse('${parts[3]}-$month-${day}T${parts[4]}') ?? DateTime.now();
      }
    } catch (_) {}
    return DateTime.now();
  }

  int _readTime(String text) => (text.split(RegExp(r'\s+')).length / 200).ceil().clamp(2, 15);

  bool _isRelevant(String text) {
    final t = text.toLowerCase();
    const kw = ['fintech','payment','upi','rbi','npci','banking','lending','credit',
      'digital','wallet','neft','imps','rtgs','nbfc','loan','startup','razorpay',
      'paytm','phonepe','gpay','aadhaar','kyc','fraud','neobank','product','pm',
      'geopolitics','trade','policy','economy','ai','tech','india'];
    return kw.any(t.contains);
  }
}

class RssItem {
  final String id, title, url, rawContent, source, topic;
  final ArticleType type;
  final DateTime publishedAt;
  final int estimatedMinutes;
  const RssItem({required this.id, required this.title, required this.url,
    required this.rawContent, required this.source, required this.type,
    required this.topic, required this.publishedAt, required this.estimatedMinutes});
}

class _FeedCfg {
  final String url, source, topic;
  final ArticleType type;
  const _FeedCfg(this.url, this.source, this.type, this.topic);
}
