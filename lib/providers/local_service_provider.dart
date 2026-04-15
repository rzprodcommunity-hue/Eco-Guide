import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/local_service.dart';
import '../services/api_client.dart';
import '../services/offline_cache_service.dart';
import '../services/local_service_service.dart';
import '../core/services/connectivity_service.dart';

class LocalServiceProvider extends ChangeNotifier {
  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;
  final LocalServiceService _service;

  List<LocalService> _services = [];
  LocalService? _selectedService;
  bool _isLoading = false;
  String? _error;
  String? _filterCategory;
  String? _searchQuery;

  LocalServiceProvider(ApiClient apiClient)
    : _service = LocalServiceService(apiClient);

  List<LocalService> get services => _services;
  LocalService? get selectedService => _selectedService;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get filterCategory => _filterCategory;
  String? get searchQuery => _searchQuery;

  List<LocalService> _applyFilters(
    List<LocalService> services, {
    String? category,
    String? search,
  }) {
    final selectedSearch = search?.trim().toLowerCase();

    return services.where((service) {
      if (category != null && service.category != category) {
        return false;
      }
      if (selectedSearch != null && selectedSearch.isNotEmpty) {
        final inName = service.name.toLowerCase().contains(selectedSearch);
        final inDesc = service.description.toLowerCase().contains(
          selectedSearch,
        );
        if (!inName && !inDesc) return false;
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

  Future<List<LocalService>> _getOfflineNearbyServices(
    double lat,
    double lng, {
    String? category,
    double radiusKm = 50,
  }) async {
    final cached = await OfflineCacheService.instance.getOfflineLocalServices();
    final filteredByCategory = category == null
        ? cached
        : cached.where((service) => service.category == category).toList();

    final withDistance = <MapEntry<LocalService, double>>[];
    for (final service in filteredByCategory) {
      final sLat = service.latitude;
      final sLng = service.longitude;
      if (sLat == null || sLng == null) continue;
      final distance = _distanceKm(lat, lng, sLat, sLng);
      if (distance <= radiusKm) {
        withDistance.add(MapEntry(service, distance));
      }
    }

    withDistance.sort((a, b) => a.value.compareTo(b.value));
    return withDistance.map((entry) => entry.key).toList();
  }

  Future<void> loadServices({String? category, String? search}) async {
    _isLoading = true;
    _error = null;
    _searchQuery = search;
    notifyListeners();

    // Check connectivity
    final connectivity = ConnectivityService.instance;
    final isOffline = connectivity.isOfflineMode;
    final selectedCategory = category ?? _filterCategory;
    final selectedSearch = search ?? _searchQuery;

    if (isOffline) {
      // Use offline data directly
      final cached = await OfflineCacheService.instance.getOfflineLocalServices();
      _services = _applyFilters(
        cached,
        category: selectedCategory,
        search: selectedSearch,
      );
      _isOfflineMode = true;
      debugPrint(
        'LocalServiceProvider.loadServices[OFFLINE]: loaded ${_services.length} services '
        '(category=${selectedCategory ?? 'ALL'}, search=${selectedSearch ?? ''})',
      );
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final onlineServices = await _service.getServices(
        category: selectedCategory,
        search: selectedSearch,
      );

      if (onlineServices.isEmpty) {
        final cached = await OfflineCacheService.instance
            .getOfflineLocalServices();
        final fallback = _applyFilters(
          cached,
          category: selectedCategory,
          search: selectedSearch,
        );

        if (fallback.isNotEmpty) {
          _services = fallback;
          _isOfflineMode = true;
          debugPrint(
            'LocalServiceProvider.loadServices[FALLBACK_EMPTY_API]: using ${_services.length} offline services',
          );
        } else {
          _services = onlineServices;
          _isOfflineMode = false;
        }
      } else {
        _services = onlineServices;
        _isOfflineMode = false;
      }

      connectivity.markBackendReachable();
    } catch (e) {
      connectivity.markBackendUnreachable();
      
      // Fallback to offline
      final cached = await OfflineCacheService.instance.getOfflineLocalServices();
      if (cached.isNotEmpty) {
        _services = _applyFilters(
          cached,
          category: selectedCategory,
          search: selectedSearch,
        );
        _isOfflineMode = true;
        _error = null;
        debugPrint(
          'LocalServiceProvider.loadServices[ERROR_FALLBACK]: backend error="$e", '
          'using ${_services.length} offline services',
        );
      } else {
        _error = e.toString();
        _isOfflineMode = false;
        debugPrint(
          'LocalServiceProvider.loadServices: backend error and no offline cache: $e',
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<LocalService>> getNearbyServices(
    double lat,
    double lng, {
    String? category,
  }) async {
    final connectivity = ConnectivityService.instance;
    if (connectivity.isOfflineMode) {
      _isOfflineMode = true;
      return _getOfflineNearbyServices(lat, lng, category: category);
    }

    try {
      final nearby = await _service.getNearbyServices(
        lat: lat,
        lng: lng,
        category: category,
      );
      connectivity.markBackendReachable();

      if (nearby.isEmpty) {
        final fallback = await _getOfflineNearbyServices(
          lat,
          lng,
          category: category,
        );
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
      final fallback = await _getOfflineNearbyServices(
        lat,
        lng,
        category: category,
      );
      if (fallback.isNotEmpty) {
        _isOfflineMode = true;
        return fallback;
      }
      return [];
    }
  }

  Future<void> loadServiceById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final connectivity = ConnectivityService.instance;
    if (connectivity.isOfflineMode) {
      final cached = await OfflineCacheService.instance.getOfflineLocalServices();
      LocalService? local;
      for (final service in cached) {
        if (service.id == id) {
          local = service;
          break;
        }
      }

      _selectedService = local;
      _isOfflineMode = true;
      _error = local == null ? 'Service indisponible hors ligne' : null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _selectedService = await _service.getServiceById(id);
      _isOfflineMode = false;
      connectivity.markBackendReachable();
    } catch (e) {
      connectivity.markBackendUnreachable();
      final cached = await OfflineCacheService.instance
          .getOfflineLocalServices();
      LocalService? local;
      for (final service in cached) {
        if (service.id == id) {
          local = service;
          break;
        }
      }

      if (local != null) {
        _selectedService = local;
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

  void setCategoryFilter(String? category) {
    _filterCategory = category;
    loadServices(search: _searchQuery);
  }

  void clearSelection() {
    _selectedService = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
