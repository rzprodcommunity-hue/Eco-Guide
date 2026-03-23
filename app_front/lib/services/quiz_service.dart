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
    final data = response['data'] as List? ?? [];
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
    final data = response['data'] as List? ?? response as List;
    return data
        .map((json) => Quiz.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Quiz>> getQuizzesByCategory(String category) async {
    final response =
        await _client.get('${ApiConstants.quizzes}/category/$category');
    final data = response['data'] as List? ?? response as List;
    return data
        .map((json) => Quiz.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Quiz>> getQuizzesByTrail(String trailId) async {
    final response =
        await _client.get('${ApiConstants.quizzes}/trail/$trailId');
    final data = response['data'] as List? ?? response as List;
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
    final data = response as List? ?? [];
    return data
        .map((json) => CategoryStats.fromJson(json as Map<String, dynamic>))
        .toList();
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
    final data = response as List? ?? [];
    return data
        .map((json) => QuizScore.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<QuizScore>> getLeaderboard({String? category, int limit = 10}) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (category != null) 'category': category,
    };
    final response = await _client
        .get('${ApiConstants.quizzes}/scores/leaderboard', queryParams: queryParams);
    final data = response as List? ?? [];
    return data
        .map((json) => QuizScore.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
