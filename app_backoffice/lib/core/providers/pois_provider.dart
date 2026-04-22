import 'package:flutter/material.dart';
import '../models/poi_model.dart';
import '../services/poi_service.dart';

class PoisProvider extends ChangeNotifier {
  List<PoiModel> _pois = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _total = 0;

  List<PoiModel> get pois => _pois;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get total => _total;

  Future<void> loadPois({int page = 1, String? type, String? trailId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await PoiService.getPois(
        page: page,
        limit: 10,
        type: type,
        trailId: trailId,
      );
      _pois = response['pois'] as List<PoiModel>;
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

  Future<bool> createPoi(Map<String, dynamic> data) async {
    try {
      await PoiService.createPoi(data);
      await loadPois(page: _currentPage);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePoi(String id, Map<String, dynamic> data) async {
    try {
      await PoiService.updatePoi(id, data);
      await loadPois(page: _currentPage);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePoi(String id) async {
    try {
      await PoiService.deletePoi(id);
      await loadPois(page: _currentPage);
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
