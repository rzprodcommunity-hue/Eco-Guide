import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/weather.dart';
import 'api_client.dart';

class WeatherService {
  final ApiClient _client;
  static const String _openMeteoBaseUrl = 'https://api.open-meteo.com/v1/forecast';

  WeatherService(this._client);

  /// Fetches current weather without depending on backend availability.
  /// Open-Meteo is queried first; backend is used only as fallback.
  Future<Weather> getCurrentWeather({double? lat, double? lng}) async {
    try {
      // Primary source: direct public weather API.
      return await _fetchFromOpenMeteo(lat, lng);
    } catch (_) {
      // Secondary fallback: backend weather endpoint.
      final queryParams = <String, String>{
        if (lat != null) 'lat': lat.toString(),
        if (lng != null) 'lng': lng.toString(),
      };

      final response = await _client.get(
        ApiConstants.weatherCurrent,
        queryParams: queryParams.isEmpty ? null : queryParams,
      );

      return Weather.fromJson(response);
    }
  }

  /// Direct call to Open-Meteo free API for real-time weather data.
  Future<Weather> _fetchFromOpenMeteo(double? lat, double? lng) async {
    final latitude = lat ?? 36.7544;  // Default: Tabarka, Tunisia
    final longitude = lng ?? 8.7580;

    final uri = Uri.parse(_openMeteoBaseUrl).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,is_day',
      'timezone': 'auto',
    });

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch weather data');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final current = payload['current'] as Map<String, dynamic>?;

    if (current == null) {
      throw Exception('Invalid weather response');
    }

    final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
    final temperature = (current['temperature_2m'] as num?)?.toDouble() ?? 0;
    final humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? 0;
    final windSpeed = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0;
    final isDay = ((current['is_day'] as num?)?.toInt() ?? 1) == 1;

    final condition = _mapCondition(weatherCode);
    final summary = _buildSummary(condition, temperature, windSpeed);

    return Weather(
      temperature: temperature,
      humidity: humidity,
      windSpeed: windSpeed,
      weatherCode: weatherCode,
      isDay: isDay,
      condition: condition,
      summary: summary,
      latitude: latitude,
      longitude: longitude,
    );
  }

  String _mapCondition(int code) {
    if (code == 0) return 'Clear';
    if ([1, 2, 3].contains(code)) return 'Partly cloudy';
    if ([45, 48].contains(code)) return 'Fog';
    if ([51, 53, 55, 56, 57].contains(code)) return 'Drizzle';
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return 'Rain';
    if ([71, 73, 75, 77, 85, 86].contains(code)) return 'Snow';
    if ([95, 96, 99].contains(code)) return 'Thunderstorm';
    return 'Variable';
  }

  String _buildSummary(String condition, double temperature, double windSpeed) {
    if (condition == 'Clear' && temperature >= 18 && windSpeed < 20) {
      return 'Perfect for hiking';
    }
    if (condition == 'Rain' || condition == 'Thunderstorm') {
      return 'Trail caution recommended';
    }
    if (temperature < 8) {
      return 'Cold conditions expected';
    }
    return 'Good outdoor conditions';
  }
}
