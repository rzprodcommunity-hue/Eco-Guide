import 'package:flutter/material.dart';
import '../models/local_service.dart';
import '../services/api_client.dart';
import '../services/local_service_service.dart';

class LocalServiceProvider extends ChangeNotifier {
  final LocalServiceService _service;

  List<LocalService> _services = [];
  LocalService? _selectedService;
  bool _isLoading = false;
  String? _error;
  String? _filterCategory;

  LocalServiceProvider(ApiClient apiClient) : _service = LocalServiceService(apiClient);

  List<LocalService> get services => _services;
  LocalService? get selectedService => _selectedService;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get filterCategory => _filterCategory;

  Future<void> loadServices({String? category}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _services = await _service.getServices(category: category ?? _filterCategory);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<LocalService>> getNearbyServices(double lat, double lng, {String? category}) async {
    try {
      return await _service.getNearbyServices(lat: lat, lng: lng, category: category);
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
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCategoryFilter(String? category) {
    _filterCategory = category;
    loadServices();
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
