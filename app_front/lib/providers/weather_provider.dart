import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../services/api_client.dart';
import '../services/weather_service.dart';

class WeatherProvider extends ChangeNotifier {
  final WeatherService _service;

  Weather? _currentWeather;
  bool _isLoading = false;
  String? _error;

  WeatherProvider(ApiClient apiClient) : _service = WeatherService(apiClient);

  Weather? get currentWeather => _currentWeather;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCurrentWeather({double? lat, double? lng}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentWeather = await _service.getCurrentWeather(lat: lat, lng: lng);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
