import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Signed trail-authorization payload shared between app_geo (generator) and
/// app_front (scanner). app_geo signs `{id, name}` with a shared secret; the
/// app_front scanner re-computes the signature offline to decide whether to
/// unlock the "Démarrer" (start trail) button for that trail.
///
/// IMPORTANT: [secret] must be byte-for-byte identical to the constant in
/// app_front/lib/services/trail_unlock_service.dart, otherwise valid QR codes
/// will be rejected.
class TrailQr {
  TrailQr._();

  /// Shared signing secret. Keep in sync with app_front.
  static const String secret = 'EcoGuide#Tabarka-2026::trail-access::v1';

  /// Magic prefix + version so the scanner can reject unrelated QR codes early.
  static const String _prefix = 'ECOGUIDE1';

  /// A generated code is only accepted within this window of its issue time.
  static const Duration validity = Duration(hours: 24);

  /// Builds the QR payload string for a selected trail.
  static String build({required String trailId, required String trailName}) {
    final body = jsonEncode({
      'id': trailId,
      'n': trailName,
      't': DateTime.now().millisecondsSinceEpoch,
    });
    final encoded = base64Url.encode(utf8.encode(body));
    final sig = _sign(encoded);
    return '$_prefix.$encoded.$sig';
  }

  /// Verifies a scanned [raw] payload. Returns the decoded trail data when the
  /// signature is valid, or `null` when the QR is missing/invalid/tampered.
  static TrailQrData? verify(String raw) {
    final value = raw.trim();
    final parts = value.split('.');
    if (parts.length != 3) return null;
    if (parts[0] != _prefix) return null;

    final encoded = parts[1];
    final providedSig = parts[2];
    if (_sign(encoded) != providedSig) return null;

    try {
      final body = jsonDecode(utf8.decode(base64Url.decode(encoded)));
      if (body is! Map) return null;
      final id = body['id'];
      final name = body['n'];
      final ts = body['t'];
      if (id is! String || id.isEmpty) return null;
      if (ts is! int) return null;
      final issuedAt = DateTime.fromMillisecondsSinceEpoch(ts);
      if (DateTime.now().difference(issuedAt) > validity) return null;
      return TrailQrData(
        trailId: id,
        trailName: name is String ? name : '',
        issuedAt: issuedAt,
      );
    } catch (_) {
      return null;
    }
  }

  static String _sign(String encoded) {
    final digest = sha256.convert(utf8.encode('$encoded::$secret'));
    // 24 hex chars is plenty for an offline anti-tamper check.
    return digest.toString().substring(0, 24);
  }
}

class TrailQrData {
  final String trailId;
  final String trailName;
  final DateTime issuedAt;

  const TrailQrData({
    required this.trailId,
    required this.trailName,
    required this.issuedAt,
  });
}
