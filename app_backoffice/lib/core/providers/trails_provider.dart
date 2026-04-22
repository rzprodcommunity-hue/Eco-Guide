import 'package:flutter/material.dart';
import '../models/trail_model.dart';
import '../services/trail_service.dart';

class TrailsProvider extends ChangeNotifier {
  List<TrailModel> _trails = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _total = 0;
  String? _filterDifficulty;
  double? _minDistance;
  double? _maxDistance;
  int? _maxDuration;

  List<TrailModel> get trails => _trails;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get total => _total;
  String? get filterDifficulty => _filterDifficulty;
  double? get minDistance => _minDistance;
  double? get maxDistance => _maxDistance;
  int? get maxDuration => _maxDuration;
  bool get hasActiveFilters => _filterDifficulty != null || _minDistance != null || _maxDistance != null || _maxDuration != null;

  Future<void> loadTrails({int page = 1, String? difficulty, String? region}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await TrailService.getTrails(
        page: page,
        limit: 10,
        difficulty: difficulty ?? _filterDifficulty,
        region: region,
        minDistance: _minDistance,
        maxDistance: _maxDistance,
        maxDuration: _maxDuration,
      );
      _trails = response['trails'] as List<TrailModel>;
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

  void setDifficultyFilter(String? difficulty) {
    _filterDifficulty = difficulty;
    loadTrails(page: 1);
  }

  void setDistanceFilter(double? minDist, double? maxDist) {
    _minDistance = minDist;
    _maxDistance = maxDist;
    loadTrails(page: 1);
  }

  void setDurationFilter(int? maxDur) {
    _maxDuration = maxDur;
    loadTrails(page: 1);
  }

  void clearAllFilters() {
    _filterDifficulty = null;
    _minDistance = null;
    _maxDistance = null;
    _maxDuration = null;
    loadTrails(page: 1);
  }

  Future<bool> createTrail(Map<String, dynamic> data) async {
    try {
      await TrailService.createTrail(data);
      await loadTrails(page: _currentPage);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTrail(String id, Map<String, dynamic> data) async {
    try {
      await TrailService.updateTrail(id, data);
      await loadTrails(page: _currentPage);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTrail(String id) async {
    try {
      await TrailService.deleteTrail(id);
      await loadTrails(page: _currentPage);
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
