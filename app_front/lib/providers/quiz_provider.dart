import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../services/api_client.dart';
import '../services/badge_service.dart';
import '../services/offline_progress_service.dart';
import '../services/quiz_service.dart';

class QuizProvider extends ChangeNotifier {
  final QuizService _service;
  final OfflineProgressService _offline = OfflineProgressService.instance;

  bool _isDownloading = false;
  String _downloadStatus = '';
  bool get isDownloading => _isDownloading;
  String get downloadStatus => _downloadStatus;

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
      _quizzes = await _service.getRandomQuizzes(
        count: count,
        category: category,
      );
      if (_quizzes.isNotEmpty) {
        await _offline.cacheQuizzes(category ?? 'all', _quizzes);
      }
    } catch (e) {
      // Offline fallback: use cached quizzes for this category (or the pool).
      _quizzes = await _offline.getCachedQuizzes(category ?? 'all');
      if (_quizzes.length > count) _quizzes = _quizzes.sublist(0, count);
      if (_quizzes.isEmpty) _error = e.toString();
    } finally {
      if (_quizzes.isNotEmpty) _currentQuiz = _quizzes[0];
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
        await _offline.cacheQuizzes(category, _quizzes);
      }
    } catch (e) {
      _quizzes = await _offline.getCachedQuizzes(category);
      if (_quizzes.isEmpty) _error = e.toString();
    } finally {
      if (_quizzes.isNotEmpty) _currentQuiz = _quizzes[0];
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Downloads (and updates) every category's quizzes into the offline cache so
  /// the whole quiz feature works without a connection.
  Future<int> downloadAllQuizzes(List<String> categories) async {
    if (_isDownloading) return 0;
    _isDownloading = true;
    _downloadStatus = '';
    notifyListeners();
    var total = 0;
    try {
      // Random pool (mixed categories) for the "random" mode.
      try {
        final pool = await _service.getRandomQuizzes(count: 50);
        if (pool.isNotEmpty) await _offline.cacheQuizzes('all', pool);
      } catch (_) {}

      for (var i = 0; i < categories.length; i++) {
        final cat = categories[i];
        _downloadStatus = '${i + 1}/${categories.length}';
        notifyListeners();
        try {
          final qs = await _service.getQuizzesByCategory(cat);
          if (qs.isNotEmpty) {
            await _offline.cacheQuizzes(cat, qs);
            total += qs.length;
          }
        } catch (_) {}
      }
    } finally {
      _isDownloading = false;
      _downloadStatus = '';
      notifyListeners();
    }
    return total;
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
      _error = e.toString();
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
      // Offline: derive category counts from the cached quizzes.
      final cats = await _offline.getCachedCategories();
      final stats = <CategoryStats>[];
      for (final c in cats) {
        final qs = await _offline.getCachedQuizzes(c);
        stats.add(CategoryStats(category: c, quizCount: qs.length));
      }
      if (stats.isNotEmpty) {
        _categoryStats = stats;
        notifyListeners();
      }
    }
  }

  Future<void> loadUserScores() async {
    final local = await _offline.getScores();
    try {
      final remote = await _service.getMyScores();
      // Merge by category; the server value wins when present.
      final byCat = <String, QuizScore>{};
      for (final s in local) {
        byCat[s.category ?? 'general'] = s;
      }
      for (final s in remote) {
        byCat[s.category ?? 'general'] = s;
      }
      _userScores = byCat.values.toList();
    } catch (e) {
      _userScores = local;
    }
    notifyListeners();
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

  List<UserBadge> _newlyEarnedBadges = [];
  List<UserBadge> get newlyEarnedBadges => _newlyEarnedBadges;

  Future<void> finishQuiz() async {
    if (_quizzes.isEmpty) return;

    // 1) Always persist the result locally (works fully offline).
    await _offline.recordScore(
      category: _currentCategory,
      score: _score,
      correctAnswers: _correctAnswers,
      totalQuestions: _quizzes.length,
    );
    final completed = await _offline.totalQuizzesCompleted();
    _newlyEarnedBadges = await _offline.awardBadges(
      score: _score,
      correctAnswers: _correctAnswers,
      totalQuestions: _quizzes.length,
      quizzesCompleted: completed,
      category: _currentCategory,
    );
    notifyListeners();

    // 2) Best-effort sync to the backend when connected.
    try {
      await _service.submitScore(
        category: _currentCategory,
        score: _score,
        correctAnswers: _correctAnswers,
        totalQuestions: _quizzes.length,
      );
      await BadgeService.checkAndAward(
        score: _score,
        correctAnswers: _correctAnswers,
        totalQuestions: _quizzes.length,
        quizzesCompleted: completed,
        category: _currentCategory,
      );
      // Mirror any server-side badges back into the offline store.
      await _offline.mergeServerBadges(await BadgeService.getMyBadges());
    } catch (e) {
      debugPrint('Quiz online sync skipped (offline?): $e');
    }

    await loadUserScores();
  }

  /// Persists a result produced by an EXTERNAL quiz UI (e.g. the built-in
  /// offline "Nature Quiz" screen) so points and badges actually count.
  /// Offline-first: records locally first, then best-effort syncs online.
  /// Returns the badges newly earned during this call.
  Future<List<UserBadge>> recordResult({
    required int score,
    required int correctAnswers,
    required int totalQuestions,
    String? category,
  }) async {
    // 1) Always persist locally (works fully offline).
    await _offline.recordScore(
      category: category,
      score: score,
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
    );
    final completed = await _offline.totalQuizzesCompleted();
    _newlyEarnedBadges = await _offline.awardBadges(
      score: score,
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
      quizzesCompleted: completed,
      category: category,
    );
    notifyListeners();

    // 2) Best-effort sync to the backend when connected.
    try {
      await _service.submitScore(
        category: category,
        score: score,
        correctAnswers: correctAnswers,
        totalQuestions: totalQuestions,
      );
      await BadgeService.checkAndAward(
        score: score,
        correctAnswers: correctAnswers,
        totalQuestions: totalQuestions,
        quizzesCompleted: completed,
        category: category,
      );
      await _offline.mergeServerBadges(await BadgeService.getMyBadges());
    } catch (e) {
      debugPrint('Quiz online sync skipped (offline?): $e');
    }

    await loadUserScores();
    return _newlyEarnedBadges;
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
