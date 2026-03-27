import 'package:flutter/material.dart';
import '../models/poi.dart';
import '../services/api_client.dart';
import '../services/offline_cache_service.dart';
import '../services/poi_service.dart';

class PoiProvider extends ChangeNotifier {
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

  Future<void> loadPois({String? type, String? trailId, String? search}) async {
    _isLoading = true;
    _error = null;
    _searchQuery = search;
    notifyListeners();

    try {
      _pois = await _service.getPois(type: type, trailId: trailId, search: search);
    } catch (e) {
      final cached = await OfflineCacheService.instance.getOfflinePois(trailId: trailId);
      if (cached.isNotEmpty) {
        _pois = _applyOfflineFilters(cached, type: type, trailId: trailId, search: search);
        _error = null;
      } else {
        _error = e.toString();
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

    try {
      _pois = await _service.getPoisByTrail(trailId);
    } catch (e) {
      final cached = await OfflineCacheService.instance.getOfflinePois(trailId: trailId);
      if (cached.isNotEmpty) {
        _pois = cached;
        _error = null;
      } else {
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Poi>> getNearbyPois(double lat, double lng, {String? type}) async {
    try {
      return await _service.getNearbyPois(lat: lat, lng: lng, type: type);
    } catch (e) {
      _error = e.toString();
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
