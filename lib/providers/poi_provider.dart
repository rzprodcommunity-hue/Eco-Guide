import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/poi.dart';
import '../services/api_client.dart';
import '../services/offline_cache_service.dart';
import '../services/poi_service.dart';
import '../core/services/connectivity_service.dart';

class PoiProvider extends ChangeNotifier {
  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;
  final PoiService _service;

  List<Poi> _pois = [];
  Poi? _selectedPoi;
  bool _isLoading = false;
  String? _error;
  String? _searchQuery;

  PoiProvider(ApiClient apiClient) : _service = PoiService(apiClient);

  List<Poi> get pois => _pois;
  Poi? get selectedPoi => _selectedPoi;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get searchQuery => _searchQuery;

  List<Poi> _applyOfflineFilters(
    List<Poi> pois, {
    String? type,
    String? trailId,
    String? search,
  }) {
    final query = search?.trim().toLowerCase();

    return pois.where((poi) {
      if (type != null && poi.type != type) {
        return false;
      }

      if (trailId != null && poi.trailId != trailId) {
        return false;
      }

      if (query != null && query.isNotEmpty) {
        final inName = poi.name.toLowerCase().contains(query);
        final inDescription = poi.description.toLowerCase().contains(query);
        if (!inName && !inDescription) return false;
      }

      return true;
    }).toList();
  }

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

  Future<List<Poi>> _getOfflineNearbyPois(
    double lat,
    double lng, {
    String? type,
    double radiusKm = 10,
  }) async {
    final cached = await OfflineCacheService.instance.getOfflinePois();
    final filteredByType = type == null
        ? cached
        : cached.where((poi) => poi.type == type).toList();

    final withDistance = <MapEntry<Poi, double>>[];
    for (final poi in filteredByType) {
      final distance = _distanceKm(lat, lng, poi.latitude, poi.longitude);
      if (distance <= radiusKm) {
        withDistance.add(MapEntry(poi, distance));
      }
    }

    withDistance.sort((a, b) => a.value.compareTo(b.value));
    return withDistance.map((entry) => entry.key).toList();
  }

  Future<List<Poi>> _loadOfflinePoisForTrail(String trailId) async {
    final specific = await OfflineCacheService.instance.getOfflinePois(
      trailId: trailId,
    );
    if (specific.isNotEmpty) {
      debugPrint(
        'PoiProvider: ${specific.length} offline POIs found for trailId=$trailId',
      );
      return specific;
    }

    final allOffline = await OfflineCacheService.instance.getOfflinePois();
    if (allOffline.isNotEmpty) {
      debugPrint(
        'PoiProvider: no trail-linked offline POIs for trailId=$trailId, '
        'fallback to ALL offline POIs (${allOffline.length})',
      );
      return allOffline;
    }

    debugPrint(
      'PoiProvider: no trail-linked offline POIs and no offline cache for trailId=$trailId',
    );

    return const [];
  }

  Future<void> loadPois({String? type, String? trailId, String? search}) async {
    _isLoading = true;
    _error = null;
    _searchQuery = search;
    notifyListeners();

    // Check connectivity
    final connectivity = ConnectivityService.instance;
    final isOffline = connectivity.isOfflineMode;

    if (isOffline) {
      // Use offline data directly
      final cached = trailId != null
          ? await _loadOfflinePoisForTrail(trailId)
          : await OfflineCacheService.instance.getOfflinePois();
      _pois = _applyOfflineFilters(
        cached,
        type: type,
        search: search,
      );
      _isOfflineMode = true;
      debugPrint(
        'PoiProvider.loadPois[OFFLINE]: loaded ${_pois.length} POIs '
        '(trailId=${trailId ?? 'ALL'}, type=${type ?? 'ALL'}, search=${search ?? ''})',
      );
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _pois = await _service.getPois(type: type, trailId: trailId, search: search);
      debugPrint(
        'PoiProvider.loadPois[ONLINE]: API returned ${_pois.length} POIs '
        '(trailId=${trailId ?? 'ALL'}, type=${type ?? 'ALL'}, search=${search ?? ''})',
      );

      if (_pois.isEmpty) {
        final cached = trailId != null
            ? await _loadOfflinePoisForTrail(trailId)
            : await OfflineCacheService.instance.getOfflinePois();
        if (cached.isNotEmpty) {
          _pois = _applyOfflineFilters(
            cached,
            type: type,
            search: search,
          );
          _isOfflineMode = true;
          debugPrint(
            'PoiProvider.loadPois[FALLBACK_EMPTY_API]: using ${_pois.length} offline POIs',
          );
        } else {
          _isOfflineMode = false;
          debugPrint('PoiProvider.loadPois: no POIs from API and no offline cache');
        }
      } else {
        _isOfflineMode = false;
      }

      connectivity.markBackendReachable();
    } catch (e) {
      connectivity.markBackendUnreachable();
      
      // Fallback to offline
      final cached = trailId != null
          ? await _loadOfflinePoisForTrail(trailId)
          : await OfflineCacheService.instance.getOfflinePois();
      if (cached.isNotEmpty) {
        _pois = _applyOfflineFilters(
          cached,
          type: type,
          search: search,
        );
        _isOfflineMode = true;
        _error = null;
        debugPrint(
          'PoiProvider.loadPois[ERROR_FALLBACK]: backend error="$e", '
          'using ${_pois.length} offline POIs',
        );
      } else {
        _error = e.toString();
        _isOfflineMode = false;
        debugPrint(
          'PoiProvider.loadPois: backend error and no offline POIs available: $e',
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPoisByTrail(String trailId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final connectivity = ConnectivityService.instance;
    if (connectivity.isOfflineMode) {
      final cached = await _loadOfflinePoisForTrail(trailId);
      _pois = cached;
      _isOfflineMode = true;
      debugPrint(
        'PoiProvider.loadPoisByTrail[OFFLINE]: loaded ${_pois.length} POIs for trailId=$trailId',
      );
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _pois = await _service.getPoisByTrail(trailId);
      debugPrint(
        'PoiProvider.loadPoisByTrail[ONLINE]: API returned ${_pois.length} POIs for trailId=$trailId',
      );

      if (_pois.isEmpty) {
        final cached = await _loadOfflinePoisForTrail(trailId);
        if (cached.isNotEmpty) {
          _pois = cached;
          _isOfflineMode = true;
          debugPrint(
            'PoiProvider.loadPoisByTrail[FALLBACK_EMPTY_API]: using ${_pois.length} offline POIs for trailId=$trailId',
          );
        } else {
          _isOfflineMode = false;
          debugPrint(
            'PoiProvider.loadPoisByTrail: no POIs from API and no offline fallback for trailId=$trailId',
          );
        }
      } else {
        _isOfflineMode = false;
      }

      connectivity.markBackendReachable();
    } catch (e) {
      connectivity.markBackendUnreachable();
      final cached = await _loadOfflinePoisForTrail(trailId);
      if (cached.isNotEmpty) {
        _pois = cached;
        _isOfflineMode = true;
        _error = null;
        debugPrint(
          'PoiProvider.loadPoisByTrail[ERROR_FALLBACK]: backend error="$e", '
          'using ${_pois.length} offline POIs for trailId=$trailId',
        );
      } else {
        _error = e.toString();
        _isOfflineMode = false;
        debugPrint(
          'PoiProvider.loadPoisByTrail: backend error and no offline POIs for trailId=$trailId -> $e',
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Poi>> getNearbyPois(double lat, double lng, {String? type}) async {
    final connectivity = ConnectivityService.instance;
    if (connectivity.isOfflineMode) {
      _isOfflineMode = true;
      return _getOfflineNearbyPois(lat, lng, type: type);
    }

    try {
      final nearby = await _service.getNearbyPois(lat: lat, lng: lng, type: type);
      connectivity.markBackendReachable();

      if (nearby.isEmpty) {
        final fallback = await _getOfflineNearbyPois(lat, lng, type: type);
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
      final fallback = await _getOfflineNearbyPois(lat, lng, type: type);
      if (fallback.isNotEmpty) {
        _isOfflineMode = true;
        return fallback;
      }
      return [];
    }
  }

  Future<void> loadPoiById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedPoi = await _service.getPoiById(id);
    } catch (e) {
      final cached = await OfflineCacheService.instance.getOfflinePois();
      Poi? local;
      for (final poi in cached) {
        if (poi.id == id) {
          local = poi;
          break;
        }
      }

      if (local != null) {
        _selectedPoi = local;
        _error = null;
      } else {
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSelection() {
    _selectedPoi = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
