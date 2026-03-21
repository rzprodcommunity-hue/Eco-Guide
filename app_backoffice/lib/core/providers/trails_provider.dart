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

  List<TrailModel> get trails => _trails;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get total => _total;

  Future<void> loadTrails({int page = 1, String? difficulty, String? region}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await TrailService.getTrails(
        page: page,
        limit: 10,
        difficulty: difficulty,
        region: region,
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
