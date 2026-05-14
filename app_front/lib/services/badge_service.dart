import 'package:supabase_flutter/supabase_flutter.dart';

class UserBadge {
  final String key;
  final String label;
  final String description;
  final String icon;
  final String color;
  final DateTime earnedAt;

  const UserBadge({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.earnedAt,
  });

  factory UserBadge.fromJson(Map<String, dynamic> json) => UserBadge(
        key: json['badge_key'] as String,
        label: json['label'] as String,
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String? ?? 'military_tech',
        color: json['color'] as String? ?? 'F8EFCB',
        earnedAt: DateTime.tryParse(json['earned_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

// All possible badges with their criteria
const _badgeDefinitions = [
  {
    'key': 'first_quiz',
    'label': 'Premier Pas',
    'description': 'Terminer votre premier quiz',
    'icon': 'school',
    'color': 'FFF3E0',
    'iconColor': 'FF9800',
  },
  {
    'key': 'good_score',
    'label': 'Bon Élève',
    'description': 'Obtenir 70% ou plus',
    'icon': 'grade',
    'color': 'DFF0E3',
    'iconColor': '47B35B',
  },
  {
    'key': 'perfect_score',
    'label': 'Perfectionniste',
    'description': 'Score parfait 100%',
    'icon': 'military_tech',
    'color': 'F8EFCB',
    'iconColor': 'F4BA09',
  },
  {
    'key': 'naturalist',
    'label': 'Naturaliste',
    'description': 'Quiz catégorie Faune ou Flore',
    'icon': 'eco',
    'color': 'E8F5E9',
    'iconColor': '2E7D32',
  },
  {
    'key': 'explorer',
    'label': 'Explorateur',
    'description': 'Compléter 3 quiz',
    'icon': 'explore',
    'color': 'DDEDFС',
    'iconColor': '2996ED',
  },
  {
    'key': 'champion',
    'label': 'Champion',
    'description': 'Compléter 10 quiz',
    'icon': 'emoji_events',
    'color': 'FFF8E1',
    'iconColor': 'FFC107',
  },
];

class BadgeService {
  static final _supabase = Supabase.instance.client;
  static const _table = 'user_badges';

  static List<Map<String, dynamic>> get allDefinitions => _badgeDefinitions;

  static Future<List<UserBadge>> getMyBadges() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final data = await _supabase
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      return (data as List).map((e) => UserBadge.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Called after a quiz finishes. Awards applicable badges.
  static Future<List<UserBadge>> checkAndAward({
    required int score,
    required int correctAnswers,
    required int totalQuestions,
    required int quizzesCompleted,
    String? category,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final percentage =
        totalQuestions > 0 ? (correctAnswers / totalQuestions * 100) : 0;

    final toAward = <String>[];

    if (quizzesCompleted >= 1) toAward.add('first_quiz');
    if (percentage >= 70) toAward.add('good_score');
    if (percentage >= 100) toAward.add('perfect_score');
    if (category == 'fauna' || category == 'flora' || category == 'nature') {
      toAward.add('naturalist');
    }
    if (quizzesCompleted >= 3) toAward.add('explorer');
    if (quizzesCompleted >= 10) toAward.add('champion');

    if (toAward.isEmpty) return [];

    // Only insert badges not already earned
    final existing = await getMyBadges();
    final existingKeys = existing.map((b) => b.key).toSet();
    final newKeys = toAward.where((k) => !existingKeys.contains(k)).toList();

    if (newKeys.isEmpty) return [];

    final rows = newKeys.map((key) {
      final def = _badgeDefinitions.firstWhere((d) => d['key'] == key,
          orElse: () => {'key': key, 'label': key, 'description': ''});
      return {
        'user_id': userId,
        'badge_key': key,
        'label': def['label'],
        'description': def['description'],
        'icon': def['icon'],
        'color': def['color'],
        'earned_at': DateTime.now().toIso8601String(),
      };
    }).toList();

    try {
      final inserted = await _supabase.from(_table).insert(rows).select();
      return (inserted as List).map((e) => UserBadge.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
