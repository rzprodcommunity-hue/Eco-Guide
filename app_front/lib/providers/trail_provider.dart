import 'package:flutter/material.dart';
import '../models/trail.dart';
import '../services/api_client.dart';
import '../services/trail_service.dart';

class TrailProvider extends ChangeNotifier {
  final TrailService _service;

  List<Trail> _trails = [];
  Trail? _selectedTrail;
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  String? _filterDifficulty;

  TrailProvider(ApiClient apiClient) : _service = TrailService(apiClient);

  List<Trail> get trails => _trails;
  Trail? get selectedTrail => _selectedTrail;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  String? get filterDifficulty => _filterDifficulty;
  bool get hasMore => _currentPage < _totalPages;

  Future<void> loadTrails({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _trails = [];
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _service.getTrails(
        page: _currentPage,
        difficulty: _filterDifficulty,
      );
      _trails = refresh ? response.data : [..._trails, ...response.data];
      _totalPages = response.totalPages;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || _isLoading) return;
    _currentPage++;
    await loadTrails();
  }

  Future<void> loadTrailById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedTrail = await _service.getTrailById(id);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Trail>> getNearbyTrails(double lat, double lng) async {
    try {
      return await _service.getNearbyTrails(lat: lat, lng: lng);
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  void setDifficultyFilter(String? difficulty) {
    _filterDifficulty = difficulty;
    loadTrails(refresh: true);
  }

  void clearSelection() {
    _selectedTrail = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
