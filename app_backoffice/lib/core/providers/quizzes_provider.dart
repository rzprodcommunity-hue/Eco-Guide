import 'package:flutter/material.dart';
import '../models/quiz_model.dart';
import '../services/quiz_service.dart';

class QuizzesProvider extends ChangeNotifier {
  List<QuizModel> _quizzes = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _total = 0;

  List<QuizModel> get quizzes => _quizzes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get total => _total;

  Future<void> loadQuizzes({int page = 1}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await QuizService.getQuizzes(page: page, limit: 10);
      _quizzes = response['quizzes'] as List<QuizModel>;
      final meta = response['meta'] as Map<String, dynamic>?;
      if (meta != null) {
        _currentPage = meta['page'] ?? 1;
        _totalPages = meta['totalPages'] ?? 1;
        _total = meta['total'] ?? 0;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createQuiz(Map<String, dynamic> data) async {
    try {
      await QuizService.createQuiz(data);
      await loadQuizzes(page: _currentPage);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateQuiz(String id, Map<String, dynamic> data) async {
    try {
      await QuizService.updateQuiz(id, data);
      await loadQuizzes(page: _currentPage);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteQuiz(String id) async {
    try {
      await QuizService.deleteQuiz(id);
      await loadQuizzes(page: _currentPage);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
