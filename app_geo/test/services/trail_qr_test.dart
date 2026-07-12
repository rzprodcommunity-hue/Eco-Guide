import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_geo/services/trail_qr.dart';

void main() {
  group('TrailQr.build — generation du QR', () {
    test('produit un payload en trois segments prefixe ECOGUIDE1', () {
      final qr = TrailQr.build(trailId: 't-1', trailName: 'Jbel Chitana');
      final parts = qr.split('.');

      expect(parts, hasLength(3));
      expect(parts[0], 'ECOGUIDE1');
      expect(parts[2], hasLength(24)); // signature tronquee a 24 hex
    });

    test('deux sentiers differents produisent des payloads differents', () {
      final a = TrailQr.build(trailId: 't-1', trailName: 'A');
      final b = TrailQr.build(trailId: 't-2', trailName: 'B');

      expect(a, isNot(equals(b)));
    });
  });

  group('TrailQr.verify — aller-retour', () {
    test('un QR genere est accepte et rend les bonnes donnees', () {
      final qr = TrailQr.build(trailId: 't-1', trailName: 'Jbel Chitana');

      final data = TrailQr.verify(qr);

      expect(data, isNotNull);
      expect(data!.trailId, 't-1');
      expect(data.trailName, 'Jbel Chitana');
      expect(
        DateTime.now().difference(data.issuedAt).inSeconds,
        lessThan(5),
      );
    });

    test('tolere les espaces autour du payload scanne', () {
      final qr = TrailQr.build(trailId: 't-1', trailName: 'S');

      expect(TrailQr.verify('  $qr \n'), isNotNull);
    });

    test('accepte un nom de sentier accentue', () {
      final qr = TrailQr.build(trailId: 't-1', trailName: 'Forêt de Aïn Draham');

      expect(TrailQr.verify(qr)!.trailName, 'Forêt de Aïn Draham');
    });
  });

  group('TrailQr.verify — rejets', () {
    test('rejette une charge utile alteree (signature invalide)', () {
      final qr = TrailQr.build(trailId: 't-1', trailName: 'Jbel Chitana');
      final parts = qr.split('.');
      final forged = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'id': 't-999',
            'n': 'Sentier pirate',
            't': DateTime.now().millisecondsSinceEpoch,
          }),
        ),
      );

      // Charge utile remplacee, signature d origine conservee.
      expect(TrailQr.verify('${parts[0]}.$forged.${parts[2]}'), isNull);
    });

    test('rejette une signature tronquee ou modifiee', () {
      final parts = TrailQr.build(trailId: 't-1', trailName: 'S').split('.');

      expect(TrailQr.verify('${parts[0]}.${parts[1]}.deadbeef'), isNull);
      expect(TrailQr.verify('${parts[0]}.${parts[1]}.'), isNull);
    });

    test('rejette un prefixe etranger', () {
      final parts = TrailQr.build(trailId: 't-1', trailName: 'S').split('.');

      expect(TrailQr.verify('AUTREAPP.${parts[1]}.${parts[2]}'), isNull);
    });

    test('rejette un contenu qui n est pas un QR Eco-Guide', () {
      for (final raw in <String>[
        '',
        'bonjour',
        'https://exemple.tn',
        'a.b',
        'a.b.c.d',
      ]) {
        expect(TrailQr.verify(raw), isNull, reason: 'devrait rejeter "$raw"');
      }
    });

    test('rejette un base64 valide mais non JSON', () {
      final encoded = base64Url.encode(utf8.encode('pas du json'));
      // Signature correcte pour ce contenu, mais le corps n est pas un objet.
      final qr = TrailQr.build(trailId: 'x', trailName: 'x');
      final sig = qr.split('.')[2];

      expect(TrailQr.verify('ECOGUIDE1.$encoded.$sig'), isNull);
    });
  });

  group('TrailQr — fenetre de validite', () {
    test('la fenetre est de 24 h', () {
      expect(TrailQr.validity, const Duration(hours: 24));
    });

    test('le secret est celui partage avec app_front', () {
      // Ce test verrouille le contrat inter-applications : si le secret change
      // ici sans etre change dans app_front, tous les QR seront rejetes.
      expect(TrailQr.secret, 'EcoGuide#Tabarka-2026::trail-access::v1');
    });
  });
}
