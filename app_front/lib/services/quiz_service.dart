import '../core/constants/api_constants.dart';
import '../models/quiz.dart';
import 'api_client.dart';

class QuizService {
  final ApiClient _client;

  QuizService(this._client);

  Future<List<Quiz>> getQuizzes({int page = 1, int limit = 10}) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final response = await _client.get(ApiConstants.quizzes, queryParams: queryParams);
    final data = response['data'] as List? ?? [];
    return data.map((json) => Quiz.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Quiz>> getRandomQuizzes({int count = 5}) async {
    final queryParams = <String, String>{'count': count.toString()};
    final response = await _client.get(ApiConstants.quizzesRandom, queryParams: queryParams);
    final data = response['data'] as List? ?? response as List;
    return data.map((json) => Quiz.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Quiz>> getQuizzesByTrail(String trailId) async {
    final response = await _client.get('${ApiConstants.quizzes}/trail/$trailId');
    final data = response['data'] as List? ?? response as List;
    return data.map((json) => Quiz.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Quiz> getQuizById(String id) async {
    final response = await _client.get('${ApiConstants.quizzes}/$id');
    return Quiz.fromJson(response);
  }
}
