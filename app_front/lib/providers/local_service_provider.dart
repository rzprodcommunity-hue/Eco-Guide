import 'package:flutter/material.dart';
import '../models/local_service.dart';
import '../services/api_client.dart';
import '../services/offline_cache_service.dart';
import '../services/local_service_service.dart';

class LocalServiceProvider extends ChangeNotifier {
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

  Future<void> loadServices({String? category, String? search}) async {
    _isLoading = true;
    _error = null;
    _searchQuery = search;
    notifyListeners();

    try {
      _services = await _service.getServices(
        category: category ?? _filterCategory,
        search: search ?? _searchQuery,
      );
    } catch (e) {
      final cached = await OfflineCacheService.instance
          .getOfflineLocalServices();
      if (cached.isNotEmpty) {
        final selectedCategory = category ?? _filterCategory;
        final selectedSearch = (search ?? _searchQuery)?.trim().toLowerCase();

        _services = cached.where((service) {
          if (selectedCategory != null &&
              service.category != selectedCategory) {
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
        _error = null;
      } else {
        _error = e.toString();
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
    try {
      return await _service.getNearbyServices(
        lat: lat,
        lng: lng,
        category: category,
      );
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  Future<void> loadServiceById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedService = await _service.getServiceById(id);
    } catch (e) {
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
        _error = null;
      } else {
        _error = e.toString();
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
