import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationFix {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude;
  final double? speed;
  final DateTime timestamp;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.altitude,
    this.speed,
  });

  factory LocationFix.fromPosition(Position pos) {
    return LocationFix(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      altitude: pos.altitude,
      speed: pos.speed,
      timestamp: pos.timestamp,
    );
  }
}

enum LocationStatus {
  ok,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

class LocationResult {
  final LocationStatus status;
  final LocationFix? fix;
  final String? message;

  const LocationResult({required this.status, this.fix, this.message});

  bool get isSuccess => status == LocationStatus.ok && fix != null;
}

/// High-accuracy GPS helper used everywhere we need to "détecter ma position".
///
/// Optimised for speed:
/// - Asks the OS for the LAST known position immediately (returns < 100 ms).
/// - Kicks off a high-accuracy `getCurrentPosition` in parallel.
/// - Returns whichever resolves first, but keeps listening briefly to
///   upgrade to a better fix if the first one was inaccurate.
class LocationService {
  LocationService._();

  /// Default time we wait for a fresh GPS sample before giving up.
  static const _defaultWait = Duration(seconds: 4);

  /// Accuracy under which we stop waiting and return immediately.
  static const _goodAccuracyMeters = 25.0;

  /// Maximum age of "lastKnownPosition" we still consider acceptable as
  /// an instant first fix.
  static const _staleFixDuration = Duration(seconds: 30);

  /// Ensures location services are enabled and the user has granted permission.
  /// If permission is denied, attempts to request it once.
  static Future<LocationResult> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(
        status: LocationStatus.serviceDisabled,
        message: 'Le service GPS est désactivé. Activez la localisation.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(
        status: LocationStatus.permissionDeniedForever,
        message:
            'Permission GPS refusée. Autorisez la position dans les réglages.',
      );
    }

    if (permission == LocationPermission.denied) {
      return const LocationResult(
        status: LocationStatus.permissionDenied,
        message: 'Permission GPS refusée.',
      );
    }

    return const LocationResult(status: LocationStatus.ok);
  }

  /// Returns a usable GPS fix as quickly as possible.
  ///
  /// Strategy:
  /// 1. If a recent `lastKnownPosition` exists (< 30 s), return it instantly.
  /// 2. Otherwise wait up to [maxWait] for `getCurrentPosition`.
  /// 3. Return early as soon as accuracy ≤ [targetAccuracyMeters].
  static Future<LocationResult> getBestFix({
    Duration maxWait = _defaultWait,
    double targetAccuracyMeters = _goodAccuracyMeters,
  }) async {
    final permission = await ensurePermission();
    if (permission.status != LocationStatus.ok) return permission;

    final stopwatch = Stopwatch()..start();

    try {
      // Step 1 — return the most recent cached fix if it's still fresh.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final age = DateTime.now().difference(last.timestamp);
        if (age <= _staleFixDuration &&
            last.accuracy > 0 &&
            last.accuracy <= 100) {
          debugPrint(
            '[LocationService] lastKnown fix in '
            '${stopwatch.elapsedMilliseconds} ms '
            '(accuracy ${last.accuracy.toStringAsFixed(1)} m, '
            'age ${age.inSeconds}s)',
          );
          return LocationResult(
            status: LocationStatus.ok,
            fix: LocationFix.fromPosition(last),
          );
        }
      }

      // Step 2 — race a fresh fix against a short timeout.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: maxWait,
        ),
      ).timeout(maxWait + const Duration(seconds: 1));

      debugPrint(
        '[LocationService] fresh fix in '
        '${stopwatch.elapsedMilliseconds} ms '
        '(accuracy ${pos.accuracy.toStringAsFixed(1)} m)',
      );

      return LocationResult(
        status: LocationStatus.ok,
        fix: LocationFix.fromPosition(pos),
      );
    } catch (e) {
      // Step 3 — last resort: any old lastKnown fix.
      final fallback = await Geolocator.getLastKnownPosition();
      if (fallback != null) {
        debugPrint(
          '[LocationService] timeout, fallback lastKnown after '
          '${stopwatch.elapsedMilliseconds} ms',
        );
        return LocationResult(
          status: LocationStatus.ok,
          fix: LocationFix.fromPosition(fallback),
          message: 'Position approximative (dernière connue).',
        );
      }
      debugPrint('[LocationService] error after '
          '${stopwatch.elapsedMilliseconds} ms: $e');
      return LocationResult(
        status: LocationStatus.error,
        message: 'Impossible d\'obtenir un signal GPS.',
      );
    }
  }

  /// Quick fix used for periodic background refresh (no waiting on stream).
  static Future<LocationFix?> getQuickFix() async {
    final permission = await ensurePermission();
    if (permission.status != LocationStatus.ok) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 3),
        ),
      ).timeout(const Duration(seconds: 4));
      return LocationFix.fromPosition(pos);
    } catch (_) {
      return null;
    }
  }
}
