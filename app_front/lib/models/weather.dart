class Weather {
  final double temperature;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final bool isDay;
  final String condition;
  final String summary;
  final double latitude;
  final double longitude;

  Weather({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.isDay,
    required this.condition,
    required this.summary,
    required this.latitude,
    required this.longitude,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      humidity: (json['humidity'] as num?)?.toInt() ?? 0,
      windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0,
      weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
      isDay: json['isDay'] as bool? ?? true,
      condition: json['condition'] as String? ?? 'Variable',
      summary: json['summary'] as String? ?? 'Weather data unavailable',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }

  String get temperatureText => '${temperature.round()}°C';
  String get windText => '${windSpeed.round()} km/h';
  String get humidityText => '$humidity%';
}
