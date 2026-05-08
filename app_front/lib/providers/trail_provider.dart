import 'package:flutter/material.dart';
import '../models/trail.dart';
import '../services/api_client.dart';
import '../services/offline_cache_service.dart';
import '../services/trail_service.dart';

class TrailProvider extends ChangeNotifier {
  final TrailService _service;

  List<Trail> _trails = [];
  Trail? _selectedTrail;
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  String? _searchQuery;
  String? _filterDifficulty;
  double? _minDistance;
  double? _maxDistance;
  int? _maxDuration;

  TrailProvider(ApiClient apiClient) : _service = TrailService(apiClient);

  List<Trail> get trails => _trails;
  Trail? get selectedTrail => _selectedTrail;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  String? get searchQuery => _searchQuery;
  String? get filterDifficulty => _filterDifficulty;
  double? get minDistance => _minDistance;
  double? get maxDistance => _maxDistance;
  int? get maxDuration => _maxDuration;
  bool get hasMore => _currentPage < _totalPages;
  bool get hasActiveFilters => _filterDifficulty != null || _minDistance != null || _maxDistance != null || _maxDuration != null;

  List<Trail> _applyOfflineFilters(List<Trail> trails) {
    final query = _searchQuery?.trim().toLowerCase();

    return trails.where((trail) {
      if (query != null && query.isNotEmpty) {
        final inName = trail.name.toLowerCase().contains(query);
        final inDescription = trail.description.toLowerCase().contains(query);
        if (!inName && !inDescription) return false;
      }

      if (_filterDifficulty != null && trail.difficulty != _filterDifficulty) {
        return false;
      }

      if (_minDistance != null && trail.distance < _minDistance!) {
        return false;
      }

      if (_maxDistance != null && trail.distance > _maxDistance!) {
        return false;
      }

      if (_maxDuration != null && trail.estimatedDuration != null && trail.estimatedDuration! > _maxDuration!) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> loadTrails({bool refresh = false, String? search}) async {
    if (refresh) {
      _currentPage = 1;
      _trails = [];
    }

    _searchQuery = search ?? _searchQuery;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _service.getTrails(
        page: _currentPage,
        search: _searchQuery,
        difficulty: _filterDifficulty,
        minDistance: _minDistance,
        maxDistance: _maxDistance,
        maxDuration: _maxDuration,
      );
      _trails = refresh ? response.data : [..._trails, ...response.data];
      _totalPages = response.totalPages;
    } catch (e) {
      final cached = await OfflineCacheService.instance.getOfflineTrails();
      if (cached.isNotEmpty) {
        final filtered = _applyOfflineFilters(cached);
        _trails = filtered;
        _currentPage = 1;
        _totalPages = 1;
        _error = null;
      } else {
        _error = e.toString();
      }
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
      final cached = await OfflineCacheService.instance.getOfflineTrails();
      Trail? local;
      for (final trail in cached) {
        if (trail.id == id) {
          local = trail;
          break;
        }
      }

      if (local != null) {
        _selectedTrail = local;
        _error = null;
      } else {
        _error = e.toString();
      }
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

  void setDistanceFilter(double? minDist, double? maxDist) {
    _minDistance = minDist;
    _maxDistance = maxDist;
    loadTrails(refresh: true);
  }

  void setDurationFilter(int? maxDur) {
    _maxDuration = maxDur;
    loadTrails(refresh: true);
  }

  void clearAllFilters() {
    _filterDifficulty = null;
    _minDistance = null;
    _maxDistance = null;
    _maxDuration = null;
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
