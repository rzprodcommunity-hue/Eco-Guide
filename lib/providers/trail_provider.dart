import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/trail.dart';
import '../services/api_client.dart';
import '../services/offline_cache_service.dart';
import '../services/trail_service.dart';
import '../core/services/connectivity_service.dart';

class TrailProvider extends ChangeNotifier {
  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;
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

  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  List<Trail> _getOfflineNearbyTrails(
    List<Trail> cached,
    double lat,
    double lng, {
    double radiusKm = 50,
  }) {
    final withDistance = <MapEntry<Trail, double>>[];

    for (final trail in cached) {
      final sLat = trail.startLatitude;
      final sLng = trail.startLongitude;
      if (sLat == null || sLng == null) continue;

      final distance = _distanceKm(lat, lng, sLat, sLng);
      if (distance <= radiusKm) {
        withDistance.add(MapEntry(trail, distance));
      }
    }

    withDistance.sort((a, b) => a.value.compareTo(b.value));
    return withDistance.map((entry) => entry.key).toList();
  }

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

    // Check connectivity first
    final connectivity = ConnectivityService.instance;
    final isOffline = connectivity.isOfflineMode;

    if (isOffline) {
      // Use offline data directly
      final cached = await OfflineCacheService.instance.getOfflineTrails();
      final filtered = _applyOfflineFilters(cached);
      _trails = filtered;
      _currentPage = 1;
      _totalPages = 1;
      _isOfflineMode = true;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final response = await _service.getTrails(
        page: _currentPage,
        search: _searchQuery,
        difficulty: _filterDifficulty,
        minDistance: _minDistance,
        maxDistance: _maxDistance,
        maxDuration: _maxDuration,
      );

      if (response.data.isEmpty) {
        final cached = await OfflineCacheService.instance.getOfflineTrails();
        final filtered = _applyOfflineFilters(cached);
        if (filtered.isNotEmpty) {
          _trails = filtered;
          _currentPage = 1;
          _totalPages = 1;
          _isOfflineMode = true;
        } else {
          _trails = refresh ? response.data : [..._trails, ...response.data];
          _totalPages = response.totalPages;
          _isOfflineMode = false;
        }
      } else {
        _trails = refresh ? response.data : [..._trails, ...response.data];
        _totalPages = response.totalPages;
        _isOfflineMode = false;
      }

      connectivity.markBackendReachable();
    } catch (e) {
      connectivity.markBackendUnreachable();
      
      // Fallback to offline data
      final cached = await OfflineCacheService.instance.getOfflineTrails();
      if (cached.isNotEmpty) {
        final filtered = _applyOfflineFilters(cached);
        _trails = filtered;
        _currentPage = 1;
        _totalPages = 1;
        _isOfflineMode = true;
        _error = null;
      } else {
        _error = e.toString();
        _isOfflineMode = false;
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

    // Check connectivity
    final isOffline = ConnectivityService.instance.isOfflineMode;

    if (isOffline) {
      // Use offline data directly
      final cached = await OfflineCacheService.instance.getOfflineTrails();
      Trail? local;
      for (final trail in cached) {
        if (trail.id == id) {
          local = trail;
          break;
        }
      }
      _selectedTrail = local;
      _isOfflineMode = true;
      _error = local == null ? 'Sentier non disponible hors ligne' : null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _selectedTrail = await _service.getTrailById(id);
      _isOfflineMode = false;
      ConnectivityService.instance.markBackendReachable();
    } catch (e) {
      ConnectivityService.instance.markBackendUnreachable();
      
      // Fallback to offline
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
        _isOfflineMode = true;
        _error = null;
      } else {
        _error = e.toString();
        _isOfflineMode = false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Trail>> getNearbyTrails(double lat, double lng) async {
    final connectivity = ConnectivityService.instance;
    if (connectivity.isOfflineMode) {
      final cached = await OfflineCacheService.instance.getOfflineTrails();
      _isOfflineMode = true;
      return _getOfflineNearbyTrails(cached, lat, lng);
    }

    try {
      final nearby = await _service.getNearbyTrails(lat: lat, lng: lng);
      connectivity.markBackendReachable();

      if (nearby.isEmpty) {
        final cached = await OfflineCacheService.instance.getOfflineTrails();
        final fallback = _getOfflineNearbyTrails(cached, lat, lng);
        if (fallback.isNotEmpty) {
          _isOfflineMode = true;
          return fallback;
        }
      }

      _isOfflineMode = false;
      return nearby;
    } catch (e) {
      connectivity.markBackendUnreachable();
      _error = e.toString();
      final cached = await OfflineCacheService.instance.getOfflineTrails();
      final fallback = _getOfflineNearbyTrails(cached, lat, lng);
      if (fallback.isNotEmpty) {
        _isOfflineMode = true;
        return fallback;
      }
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
