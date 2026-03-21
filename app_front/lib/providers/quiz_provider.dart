import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../services/api_client.dart';
import '../services/quiz_service.dart';

class QuizProvider extends ChangeNotifier {
  final QuizService _service;

  List<Quiz> _quizzes = [];
  Quiz? _currentQuiz;
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedAnswer;
  bool _answered = false;
  bool _isLoading = false;
  String? _error;

  QuizProvider(ApiClient apiClient) : _service = QuizService(apiClient);

  List<Quiz> get quizzes => _quizzes;
  Quiz? get currentQuiz => _currentQuiz;
  int get currentIndex => _currentIndex;
  int get score => _score;
  int? get selectedAnswer => _selectedAnswer;
  bool get answered => _answered;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasNext => _currentIndex < _quizzes.length - 1;
  bool get isFinished => _currentIndex >= _quizzes.length - 1 && _answered;
  int get totalQuestions => _quizzes.length;

  Future<void> loadRandomQuizzes({int count = 5}) async {
    _isLoading = true;
    _error = null;
    _resetQuiz();
    notifyListeners();

    try {
      _quizzes = await _service.getRandomQuizzes(count: count);
      if (_quizzes.isNotEmpty) {
        _currentQuiz = _quizzes[0];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadQuizzesByTrail(String trailId) async {
    _isLoading = true;
    _error = null;
    _resetQuiz();
    notifyListeners();

    try {
      _quizzes = await _service.getQuizzesByTrail(trailId);
      if (_quizzes.isNotEmpty) {
        _currentQuiz = _quizzes[0];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectAnswer(int index) {
    if (_answered) return;
    _selectedAnswer = index;
    notifyListeners();
  }

  void submitAnswer() {
    if (_selectedAnswer == null || _answered || _currentQuiz == null) return;

    _answered = true;
    if (_currentQuiz!.isCorrect(_selectedAnswer!)) {
      _score += _currentQuiz!.points;
    }
    notifyListeners();
  }

  void nextQuestion() {
    if (!hasNext) return;

    _currentIndex++;
    _currentQuiz = _quizzes[_currentIndex];
    _selectedAnswer = null;
    _answered = false;
    notifyListeners();
  }

  void _resetQuiz() {
    _currentIndex = 0;
    _score = 0;
    _selectedAnswer = null;
    _answered = false;
    _currentQuiz = null;
    _quizzes = [];
  }

  void restart() {
    _resetQuiz();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
