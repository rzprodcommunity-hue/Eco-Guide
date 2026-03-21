import 'package:flutter/material.dart';
import '../models/local_service_model.dart';
import '../services/local_service_api_service.dart';

class LocalServicesProvider extends ChangeNotifier {
  List<LocalServiceModel> _services = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _total = 0;

  List<LocalServiceModel> get services => _services;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get total => _total;

  Future<void> loadServices({int page = 1, String? category}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await LocalServiceApiService.getServices(
        page: page,
        limit: 10,
        category: category,
      );
      _services = response['services'] as List<LocalServiceModel>;
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

  Future<bool> createService(Map<String, dynamic> data) async {
    try {
      await LocalServiceApiService.createService(data);
      await loadServices(page: _currentPage);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateService(String id, Map<String, dynamic> data) async {
    try {
      await LocalServiceApiService.updateService(id, data);
      await loadServices(page: _currentPage);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteService(String id) async {
    try {
      await LocalServiceApiService.deleteService(id);
      await loadServices(page: _currentPage);
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
