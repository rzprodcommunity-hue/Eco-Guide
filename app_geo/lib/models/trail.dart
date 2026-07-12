import 'dart:math' as math;

import 'track_point.dart';

class Trail {
  final String id;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<TrackPoint> points;

  const Trail({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.points,
    this.endedAt,
  });

  Duration get duration {
    if (points.isEmpty) return Duration.zero;
    final end = endedAt ?? points.last.timestamp;
    return end.difference(startedAt);
  }

  /// Total distance in meters along the recorded points.
  double get distanceMeters {
    if (points.length < 2) return 0;
    double total = 0;
    for (var i = 1; i < points.length; i++) {
      total += _haversine(points[i - 1], points[i]);
    }
    return total;
  }

  /// Average speed in m/s.
  double get averageSpeed {
    final secs = duration.inSeconds;
    if (secs == 0) return 0;
    return distanceMeters / secs;
  }

  /// Max speed in m/s, based on per-point speed when available.
  double get maxSpeed {
    double maxV = 0;
    for (final p in points) {
      final v = p.speed ?? 0;
      if (v > maxV) maxV = v;
    }
    return maxV;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory Trail.fromJson(Map<String, dynamic> json) => Trail(
        id: json['id'] as String,
        name: json['name'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: json['endedAt'] == null
            ? null
            : DateTime.parse(json['endedAt'] as String),
        points: (json['points'] as List<dynamic>)
            .map((e) => TrackPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static double _haversine(TrackPoint a, TrackPoint b) {
    const r = 6371000.0; // earth radius (m)
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return r * c;
  }

  static double _deg2rad(double deg) => deg * math.pi / 180.0;
}
