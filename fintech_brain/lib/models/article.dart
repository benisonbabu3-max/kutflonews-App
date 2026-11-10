import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../utils/theme.dart';

part 'article.g.dart';

@HiveType(typeId: 0)
class Article extends HiveObject {
  @HiveField(0)  final String id;
  @HiveField(1)  final String title;
  @HiveField(2)  final String url;
  @HiveField(3)  final String summary;
  @HiveField(4)  final String whyItMatters;
  @HiveField(5)  final String source;
  @HiveField(6)  final ArticleType type;
  @HiveField(7)  final DateTime publishedAt;
  @HiveField(8)  bool isRead;
  @HiveField(9)  bool isSaved;
  @HiveField(10) DateTime? savedAt;
  @HiveField(11) DateTime? lastReviewedAt;
  @HiveField(12) final String topic;
  @HiveField(13) final int estimatedMinutes;

  Article({
    required this.id,
    required this.title,
    required this.url,
    required this.summary,
    required this.whyItMatters,
    required this.source,
    required this.type,
    required this.publishedAt,
    this.isRead = false,
    this.isSaved = false,
    this.savedAt,
    this.lastReviewedAt,
    required this.topic,
    this.estimatedMinutes = 5,
  });

  bool get needsReview {
    if (!isSaved) return false;
    final ref = lastReviewedAt ?? savedAt;
    if (ref == null) return false;
    return DateTime.now().difference(ref).inDays >= 7;
  }
}

@HiveType(typeId: 1)
enum ArticleType {
  @HiveField(0) rbiCircular,
  @HiveField(1) npciUpdate,
  @HiveField(2) productBlog,
  @HiveField(3) news,
  @HiveField(4) research,
  @HiveField(5) geopolitics,
  @HiveField(6) career,
}

extension ArticleTypeX on ArticleType {
  String get label {
    switch (this) {
      case ArticleType.rbiCircular:  return 'RBI Circular';
      case ArticleType.npciUpdate:   return 'NPCI Update';
      case ArticleType.productBlog:  return 'Product Blog';
      case ArticleType.news:         return 'News';
      case ArticleType.research:     return 'Research';
      case ArticleType.geopolitics:  return 'Geopolitics';
      case ArticleType.career:       return 'Career Intel';
    }
  }

  Color get color {
    switch (this) {
      case ArticleType.rbiCircular:  return AppColors.regulation;
      case ArticleType.npciUpdate:   return AppColors.payments;
      case ArticleType.productBlog:  return AppColors.product;
      case ArticleType.news:         return AppColors.startups;
      case ArticleType.research:     return AppColors.strategy;
      case ArticleType.geopolitics:  return AppColors.geopolitics;
      case ArticleType.career:       return AppColors.aiTech;
    }
  }

  // Card background colours for swipe deck
  Color get cardBg {
    switch (this) {
      case ArticleType.rbiCircular:  return AppColors.accent;
      case ArticleType.npciUpdate:   return const Color(0xFF2C3E60);
      case ArticleType.productBlog:  return AppColors.sand;
      case ArticleType.news:         return AppColors.nearBlack;
      case ArticleType.research:     return const Color(0xFF2A4A2A);
      case ArticleType.geopolitics:  return const Color(0xFF1A5FA8);
      case ArticleType.career:       return const Color(0xFF5A2D82);
    }
  }

  Color get cardBorder {
    switch (this) {
      case ArticleType.rbiCircular:  return AppColors.accentDark;
      case ArticleType.npciUpdate:   return const Color(0xFF1A2840);
      case ArticleType.productBlog:  return AppColors.sandBorder;
      case ArticleType.news:         return const Color(0xFF2E2E2C);
      case ArticleType.research:     return const Color(0xFF162A16);
      case ArticleType.geopolitics:  return const Color(0xFF0F3A6A);
      case ArticleType.career:       return const Color(0xFF3A1A5A);
    }
  }

  bool get isDarkCard {
    switch (this) {
      case ArticleType.productBlog: return false;
      default: return true;
    }
  }
}
