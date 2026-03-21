import '../constants/api_constants.dart';
import '../models/quiz_model.dart';
import 'api_service.dart';

class QuizService {
  static Future<Map<String, dynamic>> getQuizzes({
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      'includeInactive': 'true',
    };

    final response = await ApiService.get(
      ApiConstants.quizzes,
      queryParams: queryParams,
    );

    final data = response['data'] as List;
    return {
      'quizzes': data.map((json) => QuizModel.fromJson(json)).toList(),
      'meta': response['meta'],
    };
  }

  static Future<QuizModel> getQuiz(String id) async {
    final response = await ApiService.get('${ApiConstants.quizzes}/$id');
    return QuizModel.fromJson(response);
  }

  static Future<QuizModel> createQuiz(Map<String, dynamic> data) async {
    final response = await ApiService.post(ApiConstants.quizzes, body: data);
    return QuizModel.fromJson(response);
  }

  static Future<QuizModel> updateQuiz(String id, Map<String, dynamic> data) async {
    final response = await ApiService.patch('${ApiConstants.quizzes}/$id', body: data);
    return QuizModel.fromJson(response);
  }

  static Future<void> deleteQuiz(String id) async {
    await ApiService.delete('${ApiConstants.quizzes}/$id');
  }
}
