import 'dart:async';
import 'package:geolocator/geolocator.dart';

import '../models/track_point.dart';

class LocationService {
  StreamSubscription<Position>? _sub;

  /// Request the permissions needed to track in foreground + background.
  /// Returns true if at least foreground access (while-in-use) is granted.
  Future<bool> ensurePermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return false;
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  /// Returns the current best-effort position once.
  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Snappy two-step position: returns the last known fix instantly (so the
  /// map can move right away), then upgrades to a fresh medium-accuracy fix
  /// with a short timeout.
  ///
  /// Calls [onFix] every time a new (better) position is available — usually
  /// twice: once with the cached fix and once with the live one.
  Future<void> bestEffortPosition({
    required void Function(Position fix) onFix,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    // 1) Last known — instant. Skipped if absent.
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) onFix(last);
    } catch (_) {}
    // 2) Fresh fix with a hard timeout so we never hang the UI.
    try {
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );
      onFix(fresh);
    } catch (_) {/* timed out — keep the last-known fix */}
  }

  /// Start streaming positions. Calls [onPoint] each time a new fix arrives.
  /// On Android, an ongoing notification keeps the foreground service alive
  /// so tracking continues with the screen off.
  void start({
    required void Function(TrackPoint point) onPoint,
    int distanceFilterMeters = 5,
  }) {
    _sub?.cancel();

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Enregistrement du trajet',
        notificationText: 'Le GPS est actif en arrière-plan',
        enableWakeLock: true,
      ),
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen((
      pos,
    ) {
      onPoint(
        TrackPoint(
          latitude: pos.latitude,
          longitude: pos.longitude,
          altitude: pos.altitude,
          speed: pos.speed,
          accuracy: pos.accuracy,
          timestamp: pos.timestamp,
        ),
      );
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  bool get isRunning => _sub != null;
}
