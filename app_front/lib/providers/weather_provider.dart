import 'dart:async';
import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../services/api_client.dart';
import '../services/weather_service.dart';

class WeatherProvider extends ChangeNotifier {
  final WeatherService _service;

  Weather? _currentWeather;
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;
  DateTime? _lastFetchTime;

  /// Auto-refresh interval (every 10 minutes)
  static const Duration _refreshInterval = Duration(minutes: 10);

  WeatherProvider(ApiClient apiClient) : _service = WeatherService(apiClient);

  Weather? get currentWeather => _currentWeather;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastFetchTime => _lastFetchTime;

  /// Whether the data is stale (older than refresh interval)
  bool get isStale {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > _refreshInterval;
  }

  Future<void> loadCurrentWeather({double? lat, double? lng}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentWeather = await _service.getCurrentWeather(lat: lat, lng: lng);
      _lastFetchTime = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start periodic auto-refresh of weather data
  void startAutoRefresh({double? lat, double? lng}) {
    stopAutoRefresh();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      loadCurrentWeather(lat: lat, lng: lng);
    });
  }

  /// Stop periodic auto-refresh
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}
