import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of scanning a trail-authorization QR code.
enum TrailUnlockStatus { success, invalid }

class TrailUnlockResult {
  final TrailUnlockStatus status;
  final String? trailId;
  final String? trailName;

  /// Short error code surfaced to the user when the QR is rejected.
  final String? errorCode;

  const TrailUnlockResult._(
    this.status, {
    this.trailId,
    this.trailName,
    this.errorCode,
  });

  factory TrailUnlockResult.success({
    required String trailId,
    required String trailName,
  }) =>
      TrailUnlockResult._(
        TrailUnlockStatus.success,
        trailId: trailId,
        trailName: trailName,
      );

  factory TrailUnlockResult.invalid(String code) =>
      TrailUnlockResult._(TrailUnlockStatus.invalid, errorCode: code);

  bool get isSuccess => status == TrailUnlockStatus.success;
}

/// Validates trail-authorization QR codes produced by app_geo and tracks which
/// trails the user has unlocked. Trails are LOCKED by default — the "Démarrer"
/// (start trail) button only works once a matching, valid QR has been scanned.
///
/// Validation is fully offline: app_geo signs `{id, name}` with a shared
/// secret and this service re-computes the signature.
///
/// IMPORTANT: [_secret] and [_prefix] must stay byte-for-byte identical to
/// app_geo/lib/services/trail_qr.dart.
class TrailUnlockService {
  TrailUnlockService._();
  static final TrailUnlockService instance = TrailUnlockService._();

  /// Shared signing secret. Keep in sync with app_geo.
  static const String _secret = 'EcoGuide#Tabarka-2026::trail-access::v1';
  static const String _prefix = 'ECOGUIDE1';

  /// A scanned code is only accepted within this window of its issue time.
  /// Must match TrailQr.validity in app_geo.
  static const Duration validity = Duration(hours: 24);

  // v2 stores an expiry timestamp per trail (the unlock itself lasts 24h).
  static const String _idsKey = 'unlocked_trail_ids_v2';
  static const String _namesKey = 'unlocked_trail_names_v2';

  /// Error code shown when the start button is tapped on a locked trail.
  static const String lockedErrorCode = 'ERR-TRAIL-403';

  /// Error code shown when a scanned QR fails signature verification.
  static const String invalidQrErrorCode = 'ERR-QR-401';

  /// Error code shown when a scanned QR is valid but older than 24h.
  static const String expiredQrErrorCode = 'ERR-QR-410';

  // Maps trail id / normalized name → unlock-expiry epoch millis.
  Map<String, int> _unlockedIds = <String, int>{};
  Map<String, int> _unlockedNames = <String, int>{};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _unlockedIds = _decodeMap(prefs.getString(_idsKey));
    _unlockedNames = _decodeMap(prefs.getString(_namesKey));
    _loaded = true;
  }

  Map<String, int> _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (k, v) => MapEntry(k.toString(), v is int ? v : int.tryParse('$v') ?? 0),
        );
      }
    } catch (_) {}
    return <String, int>{};
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idsKey, jsonEncode(_unlockedIds));
    await prefs.setString(_namesKey, jsonEncode(_unlockedNames));
  }

  bool _isLive(int? expiry) =>
      expiry != null && expiry > DateTime.now().millisecondsSinceEpoch;

  /// Whether the given trail (by id or, as a cross-app fallback, by name) has a
  /// still-valid (non-expired) unlock. Expired entries are pruned.
  Future<bool> isUnlocked({required String trailId, String? trailName}) async {
    await _ensureLoaded();
    var changed = false;

    // Prune any expired entries so they re-lock cleanly.
    _unlockedIds.removeWhere((_, exp) {
      final dead = !_isLive(exp);
      if (dead) changed = true;
      return dead;
    });
    _unlockedNames.removeWhere((_, exp) {
      final dead = !_isLive(exp);
      if (dead) changed = true;
      return dead;
    });
    if (changed) await _persist();

    if (_isLive(_unlockedIds[trailId])) return true;
    if (trailName != null && _isLive(_unlockedNames[_norm(trailName)])) {
      return true;
    }
    return false;
  }

  /// Remaining unlock time for a trail, or null if it is locked/expired.
  Future<Duration?> remaining({required String trailId, String? trailName}) async {
    await _ensureLoaded();
    final now = DateTime.now().millisecondsSinceEpoch;
    int? exp = _unlockedIds[trailId];
    if ((exp == null || exp <= now) && trailName != null) {
      exp = _unlockedNames[_norm(trailName)];
    }
    if (exp == null || exp <= now) return null;
    return Duration(milliseconds: exp - now);
  }

  /// Validates [rawPayload] from a scanned QR and, if valid, unlocks the trail
  /// for [validity] (24h). After that it re-locks until a new QR is scanned.
  Future<TrailUnlockResult> redeem(String rawPayload) async {
    final result = _verify(rawPayload);
    if (result.status == _VerifyStatus.expired) {
      return TrailUnlockResult.invalid(expiredQrErrorCode);
    }
    final data = result.data;
    if (data == null) {
      return TrailUnlockResult.invalid(invalidQrErrorCode);
    }

    await _ensureLoaded();
    final expiry = DateTime.now().add(validity).millisecondsSinceEpoch;
    _unlockedIds[data.trailId] = expiry;
    if (data.trailName.isNotEmpty) {
      _unlockedNames[_norm(data.trailName)] = expiry;
    }
    await _persist();

    return TrailUnlockResult.success(
      trailId: data.trailId,
      trailName: data.trailName,
    );
  }

  /// Re-locks a trail immediately (e.g. from a future management screen).
  Future<void> lock({required String trailId, String? trailName}) async {
    await _ensureLoaded();
    _unlockedIds.remove(trailId);
    if (trailName != null) _unlockedNames.remove(_norm(trailName));
    await _persist();
  }

  String _norm(String s) => s.trim().toLowerCase();

  // ── QR signature verification (mirror of app_geo TrailQr) ────────────────

  _VerifyResult _verify(String raw) {
    final value = raw.trim();
    final parts = value.split('.');
    if (parts.length != 3) return _VerifyResult.invalid();
    if (parts[0] != _prefix) return _VerifyResult.invalid();

    final encoded = parts[1];
    final providedSig = parts[2];
    if (_sign(encoded) != providedSig) return _VerifyResult.invalid();

    try {
      final body = jsonDecode(utf8.decode(base64Url.decode(encoded)));
      if (body is! Map) return _VerifyResult.invalid();
      final id = body['id'];
      final name = body['n'];
      final ts = body['t'];
      if (id is! String || id.isEmpty) return _VerifyResult.invalid();
      if (ts is! int) return _VerifyResult.invalid();
      final issuedAt = DateTime.fromMillisecondsSinceEpoch(ts);
      if (DateTime.now().difference(issuedAt) > validity) {
        return _VerifyResult.expired();
      }
      return _VerifyResult.ok(_QrData(id, name is String ? name : ''));
    } catch (_) {
      return _VerifyResult.invalid();
    }
  }

  String _sign(String encoded) {
    final digest = sha256.convert(utf8.encode('$encoded::$_secret'));
    return digest.toString().substring(0, 24);
  }
}

enum _VerifyStatus { ok, invalid, expired }

class _VerifyResult {
  final _VerifyStatus status;
  final _QrData? data;
  const _VerifyResult._(this.status, this.data);

  factory _VerifyResult.ok(_QrData data) =>
      _VerifyResult._(_VerifyStatus.ok, data);
  factory _VerifyResult.invalid() =>
      const _VerifyResult._(_VerifyStatus.invalid, null);
  factory _VerifyResult.expired() =>
      const _VerifyResult._(_VerifyStatus.expired, null);
}

class _QrData {
  final String trailId;
  final String trailName;
  const _QrData(this.trailId, this.trailName);
}
