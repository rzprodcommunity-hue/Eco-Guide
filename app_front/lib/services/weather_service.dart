import '../core/constants/api_constants.dart';
import '../models/weather.dart';
import 'api_client.dart';

class WeatherService {
  final ApiClient _client;

  WeatherService(this._client);

  Future<Weather> getCurrentWeather({double? lat, double? lng}) async {
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
