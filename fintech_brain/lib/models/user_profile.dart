import 'dart:convert';

class UserProfile {
  final String name;
  final String email;
  final String role;
  final String location;
  final String careerGoal;
  final List<String> interests;
  final bool notifyMorning;
  final bool notifyEvening;
  final int morningHour;
  final int eveningHour;
  final bool aiEnrichment;
  final bool aiInline;
  final bool aiBriefs;
  final bool aiWeeklyDigest;

  static const defaultInterests = [
    'Payments', 'Regulation', 'Product', 'AI & Tech', 'Startups',
  ];

  const UserProfile({
    this.name = 'User',
    this.email = '',
    this.role = '',
    this.location = '',
    this.careerGoal = '',
    this.interests = const ['Payments', 'Regulation', 'Product'],
    this.notifyMorning = true,
    this.notifyEvening = true,
    this.morningHour = 8,
    this.eveningHour = 21,
    this.aiEnrichment = true,
    this.aiInline = true,
    this.aiBriefs = true,
    this.aiWeeklyDigest = true,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'U';
  }

  UserProfile copyWith({
    String? name, String? email, String? role, String? location,
    String? careerGoal, List<String>? interests,
    bool? notifyMorning, bool? notifyEvening,
    int? morningHour, int? eveningHour,
    bool? aiEnrichment, bool? aiInline, bool? aiBriefs, bool? aiWeeklyDigest,
  }) => UserProfile(
    name: name ?? this.name, email: email ?? this.email,
    role: role ?? this.role, location: location ?? this.location,
    careerGoal: careerGoal ?? this.careerGoal,
    interests: interests ?? this.interests,
    notifyMorning: notifyMorning ?? this.notifyMorning,
    notifyEvening: notifyEvening ?? this.notifyEvening,
    morningHour: morningHour ?? this.morningHour,
    eveningHour: eveningHour ?? this.eveningHour,
    aiEnrichment: aiEnrichment ?? this.aiEnrichment,
    aiInline: aiInline ?? this.aiInline,
    aiBriefs: aiBriefs ?? this.aiBriefs,
    aiWeeklyDigest: aiWeeklyDigest ?? this.aiWeeklyDigest,
  );

  String toJsonString() => jsonEncode({
    'name': name, 'email': email, 'role': role, 'location': location,
    'careerGoal': careerGoal, 'interests': interests,
    'notifyMorning': notifyMorning, 'notifyEvening': notifyEvening,
    'morningHour': morningHour, 'eveningHour': eveningHour,
    'aiEnrichment': aiEnrichment, 'aiInline': aiInline,
    'aiBriefs': aiBriefs, 'aiWeeklyDigest': aiWeeklyDigest,
  });

  factory UserProfile.fromJsonString(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return UserProfile(
      name: m['name'] ?? 'User', email: m['email'] ?? '',
      role: m['role'] ?? '', location: m['location'] ?? '',
      careerGoal: m['careerGoal'] ?? '',
      interests: List<String>.from(m['interests'] ?? ['Payments', 'Regulation']),
      notifyMorning: m['notifyMorning'] ?? true,
      notifyEvening: m['notifyEvening'] ?? true,
      morningHour: m['morningHour'] ?? 8,
      eveningHour: m['eveningHour'] ?? 21,
      aiEnrichment: m['aiEnrichment'] ?? true,
      aiInline: m['aiInline'] ?? true,
      aiBriefs: m['aiBriefs'] ?? true,
      aiWeeklyDigest: m['aiWeeklyDigest'] ?? true,
    );
  }
}
