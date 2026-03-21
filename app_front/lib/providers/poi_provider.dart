import 'package:flutter/material.dart';
import '../models/poi.dart';
import '../services/api_client.dart';
import '../services/poi_service.dart';

class PoiProvider extends ChangeNotifier {
  final PoiService _service;

  List<Poi> _pois = [];
  Poi? _selectedPoi;
  bool _isLoading = false;
  String? _error;

  PoiProvider(ApiClient apiClient) : _service = PoiService(apiClient);

  List<Poi> get pois => _pois;
  Poi? get selectedPoi => _selectedPoi;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPois({String? type, String? trailId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pois = await _service.getPois(type: type, trailId: trailId);
    } catch (e) {
      _error = e.toString();
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
      _error = e.toString();
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
      _error = e.toString();
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
