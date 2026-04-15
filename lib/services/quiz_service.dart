import '../core/constants/api_constants.dart';
import '../models/quiz.dart';
import 'api_client.dart';

class QuizScore {
  final String id;
  final String userId;
  final String? category;
  final int totalScore;
  final int quizzesCompleted;
  final int correctAnswers;
  final int totalQuestions;
  final double bestPercentage;
  final DateTime lastPlayedAt;

  QuizScore({
    required this.id,
    required this.userId,
    this.category,
    required this.totalScore,
    required this.quizzesCompleted,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.bestPercentage,
    required this.lastPlayedAt,
  });

  double get averagePercentage =>
      totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0;

  factory QuizScore.fromJson(Map<String, dynamic> json) {
    return QuizScore(
      id: json['id'] as String,
      userId: json['userId'] as String,
      category: json['category'] as String?,
      totalScore: json['totalScore'] as int? ?? 0,
      quizzesCompleted: json['quizzesCompleted'] as int? ?? 0,
      correctAnswers: json['correctAnswers'] as int? ?? 0,
      totalQuestions: json['totalQuestions'] as int? ?? 0,
      bestPercentage: (json['bestPercentage'] as num?)?.toDouble() ?? 0,
      lastPlayedAt: DateTime.parse(
          json['lastPlayedAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

class CategoryStats {
  final String? category;
  final int quizCount;

  CategoryStats({this.category, required this.quizCount});

  factory CategoryStats.fromJson(Map<String, dynamic> json) {
    return CategoryStats(
      category: json['category'] as String?,
      quizCount: int.parse(json['quizCount'].toString()),
    );
  }

  String get categoryDisplayName {
    switch (category) {
      case 'flora':
        return 'Flore';
      case 'fauna':
        return 'Faune';
      case 'ecology':
        return 'Ecologie';
      case 'history':
        return 'Histoire';
      case 'geography':
        return 'Geographie';
      case 'safety':
        return 'Securite';
      default:
        return 'General';
    }
  }
}

class QuizBadgeModel {
  final String id;
  final String key;
  final String label;
  final String? description;
  final String? icon;
  final String? color;
  final int threshold;
  final String? category;
  final DateTime unlockedAt;

  QuizBadgeModel({
    required this.id,
    required this.key,
    required this.label,
    this.description,
    this.icon,
    this.color,
    required this.threshold,
    this.category,
    required this.unlockedAt,
  });

  factory QuizBadgeModel.fromJson(Map<String, dynamic> json) {
    return QuizBadgeModel(
      id: json['id'] as String,
      key: json['key'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      threshold: int.tryParse(json['threshold'].toString()) ?? 0,
      category: json['category'] as String?,
      unlockedAt: DateTime.tryParse(
            json['unlockedAt'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class QuizSummary {
  final int totalScore;
  final int quizzesCompleted;
  final int correctAnswers;
  final int totalQuestions;
  final double averagePercentage;
  final double bestPercentage;
  final List<QuizScore> categoryScores;
  final List<QuizBadgeModel> badges;

  QuizSummary({
    required this.totalScore,
    required this.quizzesCompleted,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.averagePercentage,
    required this.bestPercentage,
    required this.categoryScores,
    required this.badges,
  });

  factory QuizSummary.fromJson(Map<String, dynamic> json) {
    final totals = (json['totals'] as Map<String, dynamic>?) ?? const {};

    final categoryData =
        (json['categoryScores'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();

    final badgeData = (json['badges'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    return QuizSummary(
      totalScore: int.tryParse(totals['totalScore'].toString()) ?? 0,
      quizzesCompleted: int.tryParse(totals['quizzesCompleted'].toString()) ?? 0,
      correctAnswers: int.tryParse(totals['correctAnswers'].toString()) ?? 0,
      totalQuestions: int.tryParse(totals['totalQuestions'].toString()) ?? 0,
      averagePercentage:
          (totals['averagePercentage'] as num?)?.toDouble() ?? 0.0,
      bestPercentage: (totals['bestPercentage'] as num?)?.toDouble() ?? 0.0,
      categoryScores: categoryData.map(QuizScore.fromJson).toList(),
      badges: badgeData.map(QuizBadgeModel.fromJson).toList(),
    );
  }
}

class QuizService {
  final ApiClient _client;

  QuizService(this._client);

  Future<List<Quiz>> getQuizzes({int page = 1, int limit = 10}) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final response =
        await _client.get(ApiConstants.quizzes, queryParams: queryParams);
    final data = _extractList(response, candidateKeys: const ['data', 'items', 'results']);
    return data
        .map((json) => Quiz.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Quiz>> getRandomQuizzes({int count = 5, String? category}) async {
    final queryParams = <String, String>{
      'count': count.toString(),
      if (category != null) 'category': category,
    };
    final response =
        await _client.get(ApiConstants.quizzesRandom, queryParams: queryParams);
    final data = _extractList(response, candidateKeys: const ['data', 'items', 'results']);
    return data
        .map((json) => Quiz.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Quiz>> getQuizzesByCategory(String category) async {
    final response =
        await _client.get('${ApiConstants.quizzes}/category/$category');
    final data = _extractList(response, candidateKeys: const ['data', 'items', 'results']);
    return data
        .map((json) => Quiz.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Quiz>> getQuizzesByTrail(String trailId) async {
    final response =
        await _client.get('${ApiConstants.quizzes}/trail/$trailId');
    final data = _extractList(response, candidateKeys: const ['data', 'items', 'results']);
    return data
        .map((json) => Quiz.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Quiz> getQuizById(String id) async {
    final response = await _client.get('${ApiConstants.quizzes}/$id');
    return Quiz.fromJson(response);
  }

  Future<List<CategoryStats>> getCategoryStats() async {
    final response = await _client.get('${ApiConstants.quizzes}/categories');

    final data = _extractList(
      response,
      candidateKeys: const ['data', 'categories', 'stats', 'items', 'results'],
    );

    if (data.isNotEmpty) {
      return data
          .map((json) => CategoryStats.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    if (response is Map<String, dynamic>) {
      final fallback = response.entries
          .where((entry) => entry.value is num || entry.value is String)
          .map(
            (entry) => CategoryStats.fromJson({
              'category': entry.key,
              'quizCount': entry.value,
            }),
          )
          .toList();
      return fallback;
    }

    return [];
  }

  Future<QuizScore> submitScore({
    String? category,
    required int score,
    required int correctAnswers,
    required int totalQuestions,
  }) async {
    final response = await _client.post(
      '${ApiConstants.quizzes}/scores',
      body: {
        if (category != null) 'category': category,
        'score': score,
        'correctAnswers': correctAnswers,
        'totalQuestions': totalQuestions,
      },
    );
    return QuizScore.fromJson(response);
  }

  Future<List<QuizScore>> getMyScores() async {
    final response = await _client.get('${ApiConstants.quizzes}/scores/me');
    final data = _extractList(
      response,
      candidateKeys: const ['data', 'scores', 'items', 'results'],
    );
    return data
        .map((json) => QuizScore.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<QuizSummary> getMySummary() async {
    final response =
        await _client.get('${ApiConstants.quizzes}/scores/me/summary');
    return QuizSummary.fromJson(response as Map<String, dynamic>);
  }

  Future<List<QuizScore>> getLeaderboard({String? category, int limit = 10}) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (category != null) 'category': category,
    };
    final response = await _client
        .get('${ApiConstants.quizzes}/scores/leaderboard', queryParams: queryParams);
    final data = _extractList(
      response,
      candidateKeys: const ['data', 'scores', 'items', 'results'],
    );
    return data
        .map((json) => QuizScore.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  List<dynamic> _extractList(
    dynamic response, {
    List<String> candidateKeys = const ['data'],
  }) {
    if (response is List) return response;
    if (response is! Map<String, dynamic>) return const [];

    for (final key in candidateKeys) {
      final value = response[key];
      if (value is List) return value;
    }

    final nestedData = response['data'];
    if (nestedData is Map<String, dynamic>) {
      for (final key in candidateKeys) {
        final value = nestedData[key];
        if (value is List) return value;
      }
    }

    return const [];
  }
}
