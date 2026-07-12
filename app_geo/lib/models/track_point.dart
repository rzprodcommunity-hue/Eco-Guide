class TrackPoint {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? accuracy;
  final DateTime timestamp;

  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
    this.speed,
    this.accuracy,
  });

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lon': longitude,
        'alt': altitude,
        'spd': speed,
        'acc': accuracy,
        't': timestamp.toIso8601String(),
      };

  factory TrackPoint.fromJson(Map<String, dynamic> json) => TrackPoint(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lon'] as num).toDouble(),
        altitude: (json['alt'] as num?)?.toDouble(),
        speed: (json['spd'] as num?)?.toDouble(),
        accuracy: (json['acc'] as num?)?.toDouble(),
        timestamp: DateTime.parse(json['t'] as String),
      );
}
