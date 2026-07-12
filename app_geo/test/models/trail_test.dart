import 'package:flutter_test/flutter_test.dart';

import 'package:app_geo/models/track_point.dart';
import 'package:app_geo/models/trail.dart';

void main() {
  final start = DateTime.utc(2026, 5, 31, 8, 0, 0);

  TrackPoint point(
    double lat,
    double lon, {
    int minute = 0,
    double? speed,
    double? alt,
  }) => TrackPoint(
    latitude: lat,
    longitude: lon,
    speed: speed,
    altitude: alt,
    timestamp: start.add(Duration(minutes: minute)),
  );

  Trail trail(List<TrackPoint> points, {DateTime? endedAt}) => Trail(
    id: 'tr-1',
    name: 'Trajet',
    startedAt: start,
    endedAt: endedAt,
    points: points,
  );

  group('Trail.distanceMeters — calcul de Haversine', () {
    test('un trajet de moins de 2 points mesure 0 m', () {
      expect(trail(const []).distanceMeters, 0);
      expect(trail([point(36.95, 8.75)]).distanceMeters, 0);
    });

    test('mesure correctement un degre de latitude (~111 km)', () {
      final t = trail([point(36.0, 8.0), point(37.0, 8.0, minute: 60)]);

      // 1 degre de latitude vaut environ 111 195 m sur une sphere de 6371 km.
      expect(t.distanceMeters, closeTo(111195, 200));
    });

    test('cumule les segments successifs', () {
      final deuxSegments = trail([
        point(36.0, 8.0),
        point(36.5, 8.0, minute: 30),
        point(37.0, 8.0, minute: 60),
      ]);
      final unSegment = trail([
        point(36.0, 8.0),
        point(37.0, 8.0, minute: 60),
      ]);

      expect(
        deuxSegments.distanceMeters,
        closeTo(unSegment.distanceMeters, 1.0),
      );
    });

    test('deux points identiques donnent une distance nulle', () {
      final t = trail([point(36.95, 8.75), point(36.95, 8.75, minute: 10)]);

      expect(t.distanceMeters, closeTo(0, 0.001));
    });
  });

  group('Trail.duration', () {
    test('utilise endedAt quand il est renseigne', () {
      final t = trail(
        [point(36.95, 8.75), point(36.96, 8.76, minute: 20)],
        endedAt: start.add(const Duration(minutes: 45)),
      );

      expect(t.duration, const Duration(minutes: 45));
    });

    test('retombe sur l horodatage du dernier point', () {
      final t = trail([point(36.95, 8.75), point(36.96, 8.76, minute: 30)]);

      expect(t.duration, const Duration(minutes: 30));
    });

    test('un trajet sans point a une duree nulle', () {
      expect(trail(const []).duration, Duration.zero);
    });
  });

  group('Trail.averageSpeed', () {
    test('vitesse moyenne = distance / duree', () {
      final t = trail([
        point(36.0, 8.0),
        point(37.0, 8.0, minute: 60),
      ]);

      // ~111 195 m en 3600 s => ~30,9 m/s
      expect(t.averageSpeed, closeTo(111195 / 3600, 0.1));
    });

    test('renvoie 0 quand la duree est nulle (pas de division par zero)', () {
      final t = trail([point(36.0, 8.0), point(37.0, 8.0)]);

      expect(t.averageSpeed, 0);
    });
  });

  group('Trail.maxSpeed', () {
    test('retient la vitesse instantanee la plus elevee', () {
      final t = trail([
        point(36.95, 8.75, speed: 1.2),
        point(36.96, 8.76, minute: 10, speed: 3.8),
        point(36.97, 8.77, minute: 20, speed: 2.1),
      ]);

      expect(t.maxSpeed, 3.8);
    });

    test('ignore les points sans vitesse', () {
      final t = trail([
        point(36.95, 8.75),
        point(36.96, 8.76, minute: 10, speed: 2.5),
      ]);

      expect(t.maxSpeed, 2.5);
    });

    test('renvoie 0 quand aucune vitesse n est disponible', () {
      expect(trail([point(36.95, 8.75)]).maxSpeed, 0);
    });
  });

  group('Serialisation', () {
    test('aller-retour TrackPoint toJson / fromJson', () {
      final original = point(36.9544, 8.7580, speed: 1.4, alt: 120);

      final restored = TrackPoint.fromJson(original.toJson());

      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.altitude, original.altitude);
      expect(restored.speed, original.speed);
      expect(restored.timestamp, original.timestamp);
    });

    test('aller-retour Trail toJson / fromJson', () {
      final original = trail([
        point(36.95, 8.75, alt: 10),
        point(36.96, 8.76, minute: 15, alt: 40),
      ], endedAt: start.add(const Duration(minutes: 20)));

      final restored = Trail.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.startedAt, original.startedAt);
      expect(restored.endedAt, original.endedAt);
      expect(restored.points, hasLength(2));
      expect(
        restored.distanceMeters,
        closeTo(original.distanceMeters, 0.001),
      );
    });
  });
}
