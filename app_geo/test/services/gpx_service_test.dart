import 'package:flutter_test/flutter_test.dart';

import 'package:app_geo/models/track_point.dart';
import 'package:app_geo/models/trail.dart';
import 'package:app_geo/services/gpx_service.dart';

void main() {
  final service = GpxService();

  Trail sampleTrail() {
    final start = DateTime.utc(2026, 5, 31, 8, 0, 0);
    return Trail(
      id: 'tr-1',
      name: 'Boucle de Tabarka',
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 30)),
      points: [
        TrackPoint(
          latitude: 36.9544,
          longitude: 8.7580,
          altitude: 12,
          timestamp: start,
        ),
        TrackPoint(
          latitude: 36.9600,
          longitude: 8.7600,
          altitude: 48,
          timestamp: start.add(const Duration(minutes: 15)),
        ),
        TrackPoint(
          latitude: 36.9650,
          longitude: 8.7650,
          altitude: 75,
          timestamp: start.add(const Duration(minutes: 30)),
        ),
      ],
    );
  }

  group('GpxService.buildGpx — export', () {
    test('produit un document GPX 1.1 nomme', () {
      final xml = service.buildGpx(sampleTrail());

      expect(xml, contains('<gpx'));
      expect(xml, contains('version="1.1"'));
      expect(xml, contains('creator="app_geo"'));
      expect(xml, contains('Boucle de Tabarka'));
    });

    test('exporte un point de trace par point enregistre', () {
      final xml = service.buildGpx(sampleTrail());

      expect('<trkpt'.allMatches(xml).length, 3);
      expect(xml, contains('36.9544'));
      expect(xml, contains('8.758'));
    });

    test('exporte un trajet vide sans erreur', () {
      final xml = service.buildGpx(
        Trail(
          id: 'vide',
          name: 'Trajet vide',
          startedAt: DateTime.utc(2026),
          points: const [],
        ),
      );

      expect(xml, contains('<gpx'));
      expect('<trkpt'.allMatches(xml).length, 0);
    });
  });

  group('GpxService.parseGpx — import', () {
    test('aller-retour : export puis import conserve les points', () {
      final original = sampleTrail();

      final restored = service.parseGpx(
        service.buildGpx(original),
        fallbackName: 'inconnu',
      );

      expect(restored.name, 'Boucle de Tabarka');
      expect(restored.points, hasLength(3));
      expect(restored.points.first.latitude, closeTo(36.9544, 0.00001));
      expect(restored.points.first.longitude, closeTo(8.7580, 0.00001));
      expect(restored.points.last.latitude, closeTo(36.9650, 0.00001));
    });

    test('aller-retour : la distance calculee est conservee', () {
      final original = sampleTrail();

      final restored = service.parseGpx(
        service.buildGpx(original),
        fallbackName: 'inconnu',
      );

      expect(
        restored.distanceMeters,
        closeTo(original.distanceMeters, 1.0), // < 1 m d ecart
      );
    });

    test('utilise le nom de repli quand le GPX n en porte aucun', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk><trkseg>
    <trkpt lat="36.95" lon="8.75"></trkpt>
  </trkseg></trk>
</gpx>''';

      final trail = service.parseGpx(xml, fallbackName: 'randonnee.gpx');

      expect(trail.name, 'randonnee.gpx');
      expect(trail.points, hasLength(1));
    });

    test(
      'DEFAUT CONNU (ANO-G06) : un point sans coordonnees fait echouer tout l import',
      () {
        const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk><name>Test</name><trkseg>
    <trkpt lat="36.95" lon="8.75"></trkpt>
    <trkpt></trkpt>
    <trkpt lat="36.96" lon="8.76"></trkpt>
  </trkseg></trk>
</gpx>''';

        // Comportement ATTENDU : les points invalides seraient ignores et
        // l import rendrait les 2 points valides. GpxService.parseGpx contient
        // d ailleurs la garde `if (pt.lat == null || pt.lon == null) continue;`
        // (gpx_service.dart:48) prevue pour cela.
        //
        // Comportement REEL : GpxReader leve `Bad state: No element` AVANT de
        // rendre la main, donc cette garde n est jamais atteinte — c est du code
        // mort. Un GPX legerement malforme fait echouer l import entier, sans
        // message utilisateur (aucun try/catch dans l appelant).
        //
        // Ce test verrouille le comportement actuel. Quand le defaut sera
        // corrige (try/catch dans parseGpx, ou saut du point fautif), il devra
        // etre remplace par : expect(trail.points, hasLength(2));
        expect(
          () => service.parseGpx(xml, fallbackName: 'x'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('importe un GPX sans aucun point sans planter', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk><name>Vide</name><trkseg></trkseg></trk>
</gpx>''';

      final trail = service.parseGpx(xml, fallbackName: 'x');

      expect(trail.name, 'Vide');
      expect(trail.points, isEmpty);
      expect(trail.distanceMeters, 0);
    });
  });
}
