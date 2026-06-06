import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../services/api_client.dart';
import '../services/offline_cache_service.dart';
import '../services/quiz_service.dart';

class QuizProvider extends ChangeNotifier {
  final QuizService _service;

  List<Quiz> _quizzes = [];
  Quiz? _currentQuiz;
  int _currentIndex = 0;
  int _score = 0;
  int _correctAnswers = 0;
  int? _selectedAnswer;
  bool _answered = false;
  bool _isLoading = false;
  String? _error;
  String? _currentCategory;

  // Score data
  List<QuizScore> _userScores = [];
  List<CategoryStats> _categoryStats = [];

  QuizProvider(ApiClient apiClient) : _service = QuizService(apiClient);

  List<Quiz> get quizzes => _quizzes;
  Quiz? get currentQuiz => _currentQuiz;
  int get currentIndex => _currentIndex;
  int get score => _score;
  int get correctAnswers => _correctAnswers;
  int? get selectedAnswer => _selectedAnswer;
  bool get answered => _answered;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasNext => _currentIndex < _quizzes.length - 1;
  bool get isFinished => _currentIndex >= _quizzes.length - 1 && _answered;
  int get totalQuestions => _quizzes.length;
  String? get currentCategory => _currentCategory;
  List<QuizScore> get userScores => _userScores;
  List<CategoryStats> get categoryStats => _categoryStats;

  Future<void> loadRandomQuizzes({int count = 10, String? category}) async {
    _isLoading = true;
    _error = null;
    _currentCategory = category;
    _resetQuiz();
    notifyListeners();

    try {
      _quizzes = await _service.getRandomQuizzes(count: count, category: category);
      if (_quizzes.isNotEmpty) {
        _currentQuiz = _quizzes[0];
      }
    } catch (e) {
      final cached = await OfflineCacheService.instance.getOfflineQuizzes(
        category: category,
      );
      if (cached.isNotEmpty) {
        _quizzes = cached.length > count ? cached.sublist(0, count) : cached;
        _currentQuiz = _quizzes.isNotEmpty ? _quizzes[0] : null;
        _error = null;
      } else {
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadQuizzesByCategory(String category) async {
    _isLoading = true;
    _error = null;
    _currentCategory = category;
    _resetQuiz();
    notifyListeners();

    try {
      _quizzes = await _service.getQuizzesByCategory(category);
      if (_quizzes.isNotEmpty) {
        _currentQuiz = _quizzes[0];
      }
    } catch (e) {
      final cached = await OfflineCacheService.instance.getOfflineQuizzes(
        category: category,
      );
      if (cached.isNotEmpty) {
        _quizzes = cached;
        _currentQuiz = _quizzes[0];
        _error = null;
      } else {
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadQuizzesByTrail(String trailId) async {
    _isLoading = true;
    _error = null;
    _currentCategory = null;
    _resetQuiz();
    notifyListeners();

    try {
      _quizzes = await _service.getQuizzesByTrail(trailId);
      if (_quizzes.isNotEmpty) {
        _currentQuiz = _quizzes[0];
      }
    } catch (e) {
      final cached = await OfflineCacheService.instance.getOfflineQuizzes(
        trailId: trailId,
      );
      if (cached.isNotEmpty) {
        _quizzes = cached;
        _currentQuiz = _quizzes[0];
        _error = null;
      } else {
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategoryStats() async {
    try {
      _categoryStats = await _service.getCategoryStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading category stats: $e');
    }
  }

  Future<void> loadUserScores() async {
    try {
      _userScores = await _service.getMyScores();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user scores: $e');
    }
  }

  QuizScore? getScoreForCategory(String? category) {
    try {
      return _userScores.firstWhere((s) => s.category == category);
    } catch (_) {
      return null;
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
      _correctAnswers++;
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

  void skipQuestion() {
    if (_currentIndex < _quizzes.length - 1) {
      _currentIndex++;
      _currentQuiz = _quizzes[_currentIndex];
      _selectedAnswer = null;
      _answered = false;
      notifyListeners();
    } else {
      _answered = true;
      notifyListeners();
    }
  }

  Future<void> finishQuiz() async {
    if (_quizzes.isEmpty) return;

    try {
      await _service.submitScore(
        category: _currentCategory,
        score: _score,
        correctAnswers: _correctAnswers,
        totalQuestions: _quizzes.length,
      );
      await loadUserScores();
    } catch (e) {
      debugPrint('Error submitting score: $e');
    }
  }

  void _resetQuiz() {
    _currentIndex = 0;
    _score = 0;
    _correctAnswers = 0;
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
