import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quiz.dart';
import 'badge_service.dart';
import 'quiz_service.dart';

/// Per-account offline store (SharedPreferences) for everything that must work
/// without a connection: cached quizzes, quiz scores, earned badges, and
/// completed-trail history (with distances). All keys are namespaced by the
/// signed-in user id, so accounts never share data.
class OfflineProgressService {
  OfflineProgressService._();
  static final OfflineProgressService instance = OfflineProgressService._();

  String get _uid =>
      Supabase.instance.client.auth.currentUser?.id ?? 'guest';

  String _k(String suffix) => 'op_${_uid}_$suffix';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ── Quiz cache ─────────────────────────────────────────────────────────

  /// Save a list of quizzes for a [category] ('all' for the random pool).
  Future<void> cacheQuizzes(String category, List<Quiz> quizzes) async {
    final prefs = await _prefs;
    await prefs.setString(
      _k('quizzes_$category'),
      jsonEncode(quizzes.map((q) => q.toJson()).toList()),
    );
    final cats = (prefs.getStringList(_k('quiz_categories')) ?? <String>[]).toSet()
      ..add(category);
    await prefs.setStringList(_k('quiz_categories'), cats.toList());
    await prefs.setString(_k('quiz_sync_at'), DateTime.now().toIso8601String());
  }

  Future<List<Quiz>> getCachedQuizzes(String category) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_k('quizzes_$category'));
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Quiz.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> getCachedCategories() async {
    final prefs = await _prefs;
    return (prefs.getStringList(_k('quiz_categories')) ?? const <String>[])
        .where((c) => c != 'all')
        .toList();
  }

  Future<DateTime?> lastQuizSyncAt() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_k('quiz_sync_at'));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<bool> hasCachedQuizzes() async {
    final prefs = await _prefs;
    return (prefs.getStringList(_k('quiz_categories')) ?? const []).isNotEmpty;
  }

  // ── Quiz scores (aggregated per category) ───────────────────────────────

  Future<Map<String, dynamic>> _scoresMap() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_k('scores'));
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  /// Record a finished quiz into the local aggregate for its category.
  Future<void> recordScore({
    String? category,
    required int score,
    required int correctAnswers,
    required int totalQuestions,
  }) async {
    final prefs = await _prefs;
    final map = await _scoresMap();
    final key = category ?? 'general';
    final prev = (map[key] as Map?)?.cast<String, dynamic>() ?? {};

    final pct = totalQuestions > 0 ? correctAnswers / totalQuestions * 100 : 0.0;
    final prevBest = (prev['bestPercentage'] as num?)?.toDouble() ?? 0.0;

    map[key] = {
      'totalScore': ((prev['totalScore'] as num?)?.toInt() ?? 0) + score,
      'quizzesCompleted':
          ((prev['quizzesCompleted'] as num?)?.toInt() ?? 0) + 1,
      'correctAnswers':
          ((prev['correctAnswers'] as num?)?.toInt() ?? 0) + correctAnswers,
      'totalQuestions':
          ((prev['totalQuestions'] as num?)?.toInt() ?? 0) + totalQuestions,
      'bestPercentage': pct > prevBest ? pct : prevBest,
      'lastPlayedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_k('scores'), jsonEncode(map));
  }

  Future<List<QuizScore>> getScores() async {
    final map = await _scoresMap();
    final uid = _uid;
    return map.entries.map((e) {
      final v = (e.value as Map).cast<String, dynamic>();
      return QuizScore.fromJson({
        'id': 'local-${e.key}',
        'userId': uid,
        'category': e.key == 'general' ? null : e.key,
        'totalScore': v['totalScore'],
        'quizzesCompleted': v['quizzesCompleted'],
        'correctAnswers': v['correctAnswers'],
        'totalQuestions': v['totalQuestions'],
        'bestPercentage': v['bestPercentage'],
        'lastPlayedAt': v['lastPlayedAt'],
      });
    }).toList();
  }

  Future<int> totalQuizzesCompleted() async {
    final map = await _scoresMap();
    var total = 0;
    for (final v in map.values) {
      total += ((v as Map)['quizzesCompleted'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  // ── Badges ──────────────────────────────────────────────────────────────

  Future<List<UserBadge>> getBadges() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_k('badges'));
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(UserBadge.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Evaluate badge rules locally and persist newly earned badges. Returns the
  /// badges earned during THIS call (for the "new badge" celebration).
  Future<List<UserBadge>> awardBadges({
    required int score,
    required int correctAnswers,
    required int totalQuestions,
    required int quizzesCompleted,
    String? category,
  }) async {
    final pct =
        totalQuestions > 0 ? correctAnswers / totalQuestions * 100 : 0.0;
    final toAward = <String>[];
    if (quizzesCompleted >= 1) toAward.add('first_quiz');
    if (pct >= 70) toAward.add('good_score');
    if (pct >= 100) toAward.add('perfect_score');
    if (category == 'fauna' || category == 'flora' || category == 'nature') {
      toAward.add('naturalist');
    }
    if (quizzesCompleted >= 3) toAward.add('explorer');
    if (quizzesCompleted >= 10) toAward.add('champion');
    if (toAward.isEmpty) return const [];

    final existing = await getBadges();
    final existingKeys = existing.map((b) => b.key).toSet();
    final defs = BadgeService.allDefinitions;
    final now = DateTime.now().toIso8601String();

    final newOnes = <UserBadge>[];
    final stored = existing
        .map<Map<String, dynamic>>((b) => {
              'badge_key': b.key,
              'label': b.label,
              'description': b.description,
              'icon': b.icon,
              'color': b.color,
              'earned_at': b.earnedAt.toIso8601String(),
            })
        .toList();

    for (final key in toAward) {
      if (existingKeys.contains(key)) continue;
      final def = defs.firstWhere(
        (d) => d['key'] == key,
        orElse: () => {'key': key, 'label': key, 'description': ''},
      );
      final json = {
        'badge_key': key,
        'label': def['label'] ?? key,
        'description': def['description'] ?? '',
        'icon': def['icon'] ?? 'military_tech',
        'color': def['color'] ?? 'F8EFCB',
        'earned_at': now,
      };
      stored.add(json);
      newOnes.add(UserBadge.fromJson(json));
      existingKeys.add(key);
    }

    if (newOnes.isNotEmpty) {
      final prefs = await _prefs;
      await prefs.setString(_k('badges'), jsonEncode(stored));
    }
    return newOnes;
  }

  /// Mirror server-side badges into the local store (so they show offline).
  Future<void> mergeServerBadges(List<UserBadge> serverBadges) async {
    if (serverBadges.isEmpty) return;
    final existing = await getBadges();
    final byKey = {for (final b in existing) b.key: b};
    for (final b in serverBadges) {
      byKey.putIfAbsent(b.key, () => b);
    }
    final prefs = await _prefs;
    await prefs.setString(
      _k('badges'),
      jsonEncode(byKey.values
          .map((b) => {
                'badge_key': b.key,
                'label': b.label,
                'description': b.description,
                'icon': b.icon,
                'color': b.color,
                'earned_at': b.earnedAt.toIso8601String(),
              })
          .toList()),
    );
  }

  // ── Completed trails + distances ─────────────────────────────────────────

  Future<Map<String, dynamic>> _completedMap() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_k('completed_trails'));
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  /// Record a completed trail with the distance actually travelled (km).
  Future<void> markTrailCompleted({
    required String trailId,
    required String trailName,
    required double distanceKm,
    String? imageUrl,
    int? durationSeconds,
  }) async {
    final prefs = await _prefs;
    final map = await _completedMap();
    map[trailId] = {
      'trailName': trailName,
      'distanceKm': distanceKm,
      'imageUrl': imageUrl,
      'durationSeconds': durationSeconds,
      'completedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_k('completed_trails'), jsonEncode(map));
  }

  Future<Set<String>> getCompletedTrailIds() async {
    final map = await _completedMap();
    return map.keys.toSet();
  }

  Future<int> completedTrailCount() async => (await _completedMap()).length;

  /// Total distance travelled across all completed trails, in km.
  Future<double> totalDistanceKm() async {
    final map = await _completedMap();
    var total = 0.0;
    for (final v in map.values) {
      total += ((v as Map)['distanceKm'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  /// Completed-trail history, most recent first.
  Future<List<Map<String, dynamic>>> getCompletedHistory() async {
    final map = await _completedMap();
    final list = map.entries.map((e) {
      final v = (e.value as Map).cast<String, dynamic>();
      return {'trailId': e.key, ...v};
    }).toList();
    list.sort((a, b) => (b['completedAt'] as String? ?? '')
        .compareTo(a['completedAt'] as String? ?? ''));
    return list;
  }

  /// Activity magnitude per weekday (index 0 = Monday … 6 = Sunday), expressed
  /// as the total distance (km) travelled on completed trails that weekday.
  /// Used to draw the weekly activity bars on the profile — fully offline.
  Future<List<double>> getWeeklyActivityBars() async {
    final bars = List<double>.filled(7, 0);
    final map = await _completedMap();
    for (final v in map.values) {
      final m = v as Map;
      final at = DateTime.tryParse((m['completedAt'] as String?) ?? '');
      if (at == null) continue;
      final idx = (at.weekday - 1).clamp(0, 6); // Mon=0 … Sun=6
      bars[idx] += (m['distanceKm'] as num?)?.toDouble() ?? 0.0;
    }
    return bars;
  }
}
