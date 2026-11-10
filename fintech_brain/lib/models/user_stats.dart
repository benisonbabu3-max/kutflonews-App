import 'dart:convert';

class UserStats {
  final int streak;
  final int totalRead;
  final int totalSaved;
  final DateTime? lastReadDate;
  final Map<String, int> topicCounts;
  final String careerGoal;
  final String role;
  final String name;

  static const int goalTotal = 300;

  const UserStats({
    this.streak = 0,
    this.totalRead = 0,
    this.totalSaved = 0,
    this.lastReadDate,
    this.topicCounts = const {},
    this.careerGoal = '',
    this.role = '',
    this.name = '',
  });

  double get progressPercent => (totalRead / goalTotal).clamp(0.0, 1.0);

  String get topPercentile {
    if (totalRead >= 200) return 'Top 5%';
    if (totalRead >= 100) return 'Top 12%';
    if (totalRead >= 50)  return 'Top 25%';
    if (totalRead >= 20)  return 'Top 40%';
    return 'Rising';
  }

  UserStats copyWith({
    int? streak, int? totalRead, int? totalSaved,
    DateTime? lastReadDate, Map<String, int>? topicCounts,
    String? careerGoal, String? role, String? name,
  }) => UserStats(
    streak: streak ?? this.streak,
    totalRead: totalRead ?? this.totalRead,
    totalSaved: totalSaved ?? this.totalSaved,
    lastReadDate: lastReadDate ?? this.lastReadDate,
    topicCounts: topicCounts ?? this.topicCounts,
    careerGoal: careerGoal ?? this.careerGoal,
    role: role ?? this.role,
    name: name ?? this.name,
  );

  String toJsonString() => jsonEncode({
    'streak': streak, 'totalRead': totalRead, 'totalSaved': totalSaved,
    'lastReadDate': lastReadDate?.toIso8601String(),
    'topicCounts': topicCounts,
    'careerGoal': careerGoal, 'role': role, 'name': name,
  });

  factory UserStats.fromJsonString(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return UserStats(
      streak: (m['streak'] as int?) ?? 0,
      totalRead: (m['totalRead'] as int?) ?? 0,
      totalSaved: (m['totalSaved'] as int?) ?? 0,
      lastReadDate: m['lastReadDate'] != null ? DateTime.tryParse(m['lastReadDate']) : null,
      topicCounts: (m['topicCounts'] as Map<String, dynamic>? ?? {}).map((k,v) => MapEntry(k,(v as int?)??0)),
      careerGoal: (m['careerGoal'] as String?) ?? '',
      role: (m['role'] as String?) ?? '',
      name: (m['name'] as String?) ?? '',
    );
  }
}
