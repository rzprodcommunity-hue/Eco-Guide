import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/map_tile_url.dart';
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../../services/map_offline_service.dart';
import '../../services/offline_progress_service.dart';
import '../../core/widgets/eco_page_header.dart';
import '../sos/sos_button.dart';
import '../../models/local_service.dart';
import '../../models/poi.dart';
import '../../models/trail.dart';
import '../../providers/local_service_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/poi_provider.dart';
import '../../providers/trail_provider.dart';

class NavigationSosScreen extends StatefulWidget {
  final LatLng? destination;
  final String? destinationLabel;
  final Trail? trail;

  const NavigationSosScreen({
    super.key,
    this.destination,
    this.destinationLabel,
    this.trail,
  });

  @override
  State<NavigationSosScreen> createState() => _NavigationSosScreenState();
}

class _NavigationSosScreenState extends State<NavigationSosScreen> {
  static const Distance _distance = Distance();

  final MapController _mapController = MapController();
  final MapOfflineService _mapOfflineService = MapOfflineService();
  Timer? _gpsTimer;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  double _heading = 0; // Phone heading in degrees, 0 = North

  LatLng _currentPosition = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );

  LatLng? _activeDestination;
  String? _activeDestinationLabel;
  List<LatLng> _routePoints = [];

  bool _isLoading = false;
  bool _isRouting = false;
  bool _offTrailAlert = false;
  bool _offTrailMuted = false;
  // When true the user has dismissed the off-trail alert entirely: no banner,
  // no vibration, no voice. Re-enabled from the map action column at any time.
  bool _offTrailDisabled = false;
  Timer? _offTrailBuzzTimer;
  double _offTrailDistance = 0;

  _NavPhase _navPhase = _NavPhase.toPoi;
  // Distance (m) at which we announce "Vous êtes là" — the user has reached the
  // PRECISE start point (trailhead) or the destination point — and we switch
  // the off-trail reference to the trail polyline.
  static const double _reachedStartMeters = 5;
  // Distance (m) at which we fire the "you are approaching" alert.
  static const double _approachMeters = 7;
  bool _approachAnnounced = false;
  bool _arrivedAnnounced = false;

  // When there is no connection we fall back to the standard (Google "m")
  // tiles, the only ones cached for offline use — but only if a map has
  // actually been downloaded (otherwise switching changes nothing).
  bool _isOffline = false;
  bool _hasOfflineTiles = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  List<_NavPoint> _nearbyPoints = [];
  _NavPoint? _featuredPoint;

  _HikeStatus _hikeStatus = _HikeStatus.notStarted;
  bool _isFullScreen = false;
  // Hides the lines linking the current position to the start/target.
  bool _hideStartLink = false;
  DateTime? _startTime;
  Duration _elapsedTime = Duration.zero;
  double _distanceTraveled = 0.0;
  double _currentAltitude = 0.0;
  Timer? _stopwatchTimer;
  // Fixed StreamController — not recreated on every build
  late final StreamController<void> _tileResetStream;

  // Navigation enhancements
  bool _voiceEnabled = true;
  bool _initialFitDone = false;
  String? _currentInstruction;
  int _currentInstructionDistanceMeters = 0;
  List<_RouteStep> _routeSteps = [];
  DateTime? _lastSpokenInstructionTime;
  String? _lastSpokenInstructionId;
  final FlutterTts _tts = FlutterTts();

  List<LatLng> get _trailPoints {
    final points = <LatLng>[];
    if (widget.trail?.geojson != null) {
      try {
        final features = widget.trail!.geojson!['features'] as List;
        if (features.isNotEmpty) {
          final geometry = features[0]['geometry'];
          if (geometry['type'] == 'LineString') {
            final coords = geometry['coordinates'] as List;
            for (var coord in coords) {
              points.add(LatLng(coord[1], coord[0]));
            }
          }
        }
      } catch (_) {}
    }
    return points;
  }

  LatLng? get _trailStartPoint {
    final trail = widget.trail;
    if (trail?.startLatitude != null && trail?.startLongitude != null) {
      return LatLng(trail!.startLatitude!, trail.startLongitude!);
    }
    final pts = _trailPoints;
    return pts.isNotEmpty ? pts.first : null;
  }

  LatLng? get _trailEndPoint {
    final pts = _trailPoints;
    return pts.length > 1 ? pts.last : null;
  }

  @override
  void initState() {
    super.initState();
    appMapStyle.addListener(_onMapStyleChanged);
    _tileResetStream = StreamController<void>();
    _mapOfflineService.initialize();
    _initConnectivity();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_updateConnectivity);
    _activeDestination = widget.destination;
    _activeDestinationLabel = widget.destinationLabel;

    // Initial phase: if we have a trail bound, the user has to reach the
    // start first; otherwise we're navigating directly to a POI/service.
    _navPhase = widget.trail != null ? _NavPhase.goToStart : _NavPhase.toPoi;

    _tts.setSpeechRate(0.45);
    _tts.setPitch(1.0);

    // Compass — rotates user marker as phone rotates (like Google Maps)
    _compassStream = FlutterCompass.events?.listen((event) {
      final h = event.heading;
      if (h == null || !mounted) return;
      // Throttle rebuilds: only update if change >= 2°
      if ((h - _heading).abs() < 2) return;
      setState(() => _heading = h);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadMapData();
      // Try a fast fix FIRST — then jump straight to max zoom on the user.
      await _detectUserPosition();
      _startGpsTracking();
      _fitToTrailBounds();
      // Entry animation: brief overview, then zoom to user with max detail.
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      _animateToUserMaxZoom();
    });
  }

  void _animateToUserMaxZoom() {
    // Smooth Google-Maps-style entry: zoom into user position at MAX detail.
    _mapController.move(_currentPosition, 19);
  }

  /// Rebuild when the shared map style changes elsewhere (mini-map / big map)
  /// so the navigation map always reflects the latest choice.
  void _onMapStyleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appMapStyle.removeListener(_onMapStyleChanged);
    _gpsTimer?.cancel();
    _positionStream?.cancel();
    _compassStream?.cancel();
    _stopwatchTimer?.cancel();
    _offTrailBuzzTimer?.cancel();
    _tts.stop();
    _tileResetStream.close();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectivity(result);
  }

  Future<void> _updateConnectivity(List<ConnectivityResult> result) async {
    final offline =
        result.isEmpty || result.contains(ConnectivityResult.none);
    // Only switch to offline tiles when a map has actually been downloaded.
    final hasTiles =
        offline ? await _mapOfflineService.hasAnyOfflineTile() : false;
    if (offline == _isOffline && hasTiles == _hasOfflineTiles) return;
    if (!mounted) {
      _isOffline = offline;
      _hasOfflineTiles = hasTiles;
      return;
    }
    setState(() {
      _isOffline = offline;
      _hasOfflineTiles = hasTiles;
    });
    // Reload tiles so the right template (cached "standard" when offline) is used.
    if (!_tileResetStream.isClosed) _tileResetStream.add(null);
  }

  // Auto-fit the camera so the entire trail is visible (start + end + path)
  void _fitToTrailBounds() {
    if (_initialFitDone) return;
    final trailPts = _trailPoints;
    final destination = _activeDestination;
    final allPoints = <LatLng>[
      if (widget.trail?.startLatitude != null &&
          widget.trail?.startLongitude != null)
        LatLng(widget.trail!.startLatitude!, widget.trail!.startLongitude!),
      ...trailPts,
      ?destination,
    ];
    if (allPoints.length < 2) return;
    final bounds = LatLngBounds.fromPoints(allPoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 120, 40, 220),
      ),
    );
    _initialFitDone = true;
  }

  Future<void> _speak(String text, {String? id}) async {
    if (!_voiceEnabled) return;
    if (id != null && id == _lastSpokenInstructionId) {
      // Avoid repeating the same instruction within 30s
      if (_lastSpokenInstructionTime != null &&
          DateTime.now().difference(_lastSpokenInstructionTime!) <
              const Duration(seconds: 30)) {
        return;
      }
    }
    final lp = context.read<LocaleProvider>();
    final code = lp.locale.languageCode;
    await _tts.setLanguage(
      code == 'ar' ? 'ar-SA' : code == 'en' ? 'en-US' : 'fr-FR',
    );
    await _tts.stop();
    await _tts.speak(text);
    _lastSpokenInstructionId = id;
    _lastSpokenInstructionTime = DateTime.now();
  }

  Future<void> _loadMapData() async {
    final trailProvider = context.read<TrailProvider>();
    final poiProvider = context.read<PoiProvider>();
    final localServiceProvider = context.read<LocalServiceProvider>();

    setState(() => _isLoading = true);
    await Future.wait([
      trailProvider.loadTrails(refresh: true),
      poiProvider.loadPois(),
      localServiceProvider.loadServices(),
    ]);

    if (!mounted) return;
    _refreshNearbyPoints(
      trails: trailProvider.trails,
      pois: poiProvider.pois,
      services: localServiceProvider.services,
    );
    setState(() => _isLoading = false);
  }

  void _startGpsTracking() {
    _gpsTimer?.cancel();
    _positionStream?.cancel();

    // Real-time GPS stream — best accuracy for navigation, updates every meter
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1, // emit on every meter moved
      ),
    ).listen(
      (position) => _onPositionUpdate(position),
      onError: (_) {
        // If stream fails, fall back to periodic polling
        _gpsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          _updatePositionSilently();
        });
      },
    );
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    final newPos = LatLng(position.latitude, position.longitude);

    setState(() {
      if (_hikeStatus == _HikeStatus.inProgress) {
        final distanceMoved =
            _distance.as(LengthUnit.Meter, _currentPosition, newPos);
        // Filter GPS jitter: only count moves between 1m and 100m
        if (distanceMoved > 1 && distanceMoved < 100) {
          _distanceTraveled += distanceMoved / 1000;
        }
      }
      _currentPosition = newPos;
      _currentAltitude = position.altitude;
    });

    final trailProvider = context.read<TrailProvider>();
    final poiProvider = context.read<PoiProvider>();
    final localServiceProvider = context.read<LocalServiceProvider>();

    _refreshNearbyPoints(
      trails: trailProvider.trails,
      pois: poiProvider.pois,
      services: localServiceProvider.services,
    );

    _checkTargetProximity();
    _maybeAdvancePhaseAfterMove();
    _updateCurrentInstruction();
    _computeOffTrailStatus();

    // Refresh route only periodically (avoid hammering OSRM on every meter)
    _maybeRefreshRoute();
  }

  DateTime? _lastRouteRefresh;
  void _maybeRefreshRoute() {
    final now = DateTime.now();
    if (_lastRouteRefresh == null ||
        now.difference(_lastRouteRefresh!) > const Duration(seconds: 5)) {
      _lastRouteRefresh = now;
      _refreshRoute();
    }
  }

  Future<void> _startHike() async {
    // Show safety briefing dialog first
    final accepted = await _showSafetyBriefing();
    if (accepted != true || !mounted) return;

    // Check distance to trail start point
    final trail = widget.trail;
    LatLng? startPoint;
    if (trail?.startLatitude != null && trail?.startLongitude != null) {
      startPoint = LatLng(trail!.startLatitude!, trail.startLongitude!);
    } else if (_trailPoints.isNotEmpty) {
      startPoint = _trailPoints.first;
    }

    if (startPoint != null) {
      final metersToStart =
          _distance.as(LengthUnit.Meter, _currentPosition, startPoint);
      if (metersToStart > _reachedStartMeters) {
        // User is NOT at the start → first phase: route them TO the start.
        await _showAwayFromStartAlert(metersToStart, startPoint);
        if (!mounted) return;
        setState(() {
          _navPhase = _NavPhase.goToStart;
          _activeDestination = startPoint;
          _activeDestinationLabel =
              '${trail?.name ?? 'Sentier'} (point de départ)';
        });
        await _refreshRoute(force: true);
        if (!mounted) return;
      } else {
        // Already at the start → directly enter the on-trail phase.
        setState(() {
          _navPhase = _NavPhase.onTrail;
          _activeDestination = _trailEndPoint ?? startPoint;
          _activeDestinationLabel = trail?.name ?? _activeDestinationLabel;
          _routePoints = [];
        });
      }
    }

    setState(() {
      _hikeStatus = _HikeStatus.inProgress;
      _startTime ??= DateTime.now();
    });

    // Animate camera to the start point with full zoom
    if (startPoint != null) {
      _mapController.move(startPoint, 17);
    }

    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_hikeStatus == _HikeStatus.inProgress) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!);
        });
      }
    });

    _speak('Bonne randonnée. Suivez les instructions de navigation.',
        id: 'hike_started');
    _logTrailActivity('trail_started');
  }

  Future<bool?> _showSafetyBriefing() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22B53A), Color(0xFF0E7A23)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Avant de partir',
                      style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _briefItem(
                icon: Icons.gps_fixed,
                title: 'GPS et position',
                desc: 'Restez sur le sentier balisé. Hors-piste de plus '
                    'de 10 m, vous serez alerté.',
                isDark: isDark,
              ),
              _briefItem(
                icon: Icons.warning_amber_rounded,
                title: 'Bouton SOS',
                desc: 'Le bouton SOS rouge en bas envoie un signal '
                    'd\'urgence avec votre position.',
                isDark: isDark,
              ),
              _briefItem(
                icon: Icons.volume_up_rounded,
                title: 'Instructions vocales',
                desc: 'Les directions seront annoncées à voix haute. '
                    'Vous pouvez les couper.',
                isDark: isDark,
              ),
              _briefItem(
                icon: Icons.battery_charging_full,
                title: 'Batterie',
                desc: 'Économisez la batterie : verrouillez l\'écran '
                    'quand vous ne consultez pas la carte.',
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('J\'ai compris'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E7A23),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _briefItem({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF22B53A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0E7A23), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAwayFromStartAlert(double meters, LatLng startPoint) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.location_off, color: Color(0xFFE53935), size: 42),
        title: const Text('Vous n\'êtes pas au départ',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Vous êtes à environ ${meters.round()} m du point de départ. '
          'Un itinéraire vers le départ va être tracé.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E7A23),
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishHike() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Terminer la randonnée ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Votre progression sera enregistrée dans votre historique.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    _stopwatchTimer?.cancel();
    setState(() => _hikeStatus = _HikeStatus.finished);
    await _logTrailActivity('trail_completed');
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _logTrailActivity(String type) async {
    final trail = widget.trail;
    if (trail == null) return;

    // Capture before any await to avoid using context across an async gap.
    final activityService = ActivityService(context.read<ApiClient>());

    // Persist completion locally (offline-first) so the profile history,
    // completed-trail count and total distance survive without a connection.
    if (type == 'trail_completed') {
      try {
        await OfflineProgressService.instance.markTrailCompleted(
          trailId: trail.id,
          trailName: trail.name,
          distanceKm: _distanceTraveled > 0 ? _distanceTraveled : trail.distance,
          imageUrl: trail.imageUrls?.isNotEmpty == true
              ? trail.imageUrls!.first
              : null,
          durationSeconds: _elapsedTime.inSeconds,
        );
      } catch (_) {}
    }

    try {
      await activityService.logActivity(
        type: type,
        trailId: trail.id,
        metadata: {
          'trailName': trail.name,
          'imageUrl': trail.imageUrls?.isNotEmpty == true
              ? trail.imageUrls!.first
              : null,
          'distance': trail.distance,
          'duration': trail.estimatedDuration,
          'elapsedSeconds': _elapsedTime.inSeconds,
          'distanceTraveled': _distanceTraveled,
        },
      );
    } catch (_) {
      // Don't block the UI if logging fails.
    }
  }

  void _pauseHike() {
    setState(() {
      _hikeStatus = _HikeStatus.paused;
    });
  }

  void _resumeHike() {
    setState(() {
      _hikeStatus = _HikeStatus.inProgress;
      // Adjust start time so elapsed time continues smoothly
      _startTime = DateTime.now().subtract(_elapsedTime);
    });
  }

  Future<void> _detectUserPosition({bool feedback = false}) async {
    if (feedback && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Localisation en cours…'),
            duration: Duration(seconds: 2),
          ),
        );
    }
    final result = await LocationService.getBestFix();
    if (!result.isSuccess) {
      debugPrint('[GPS][nav] no fix: ${result.message}');
      if (feedback && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content:
                  Text('Localisation impossible. Activez le GPS et réessayez.'),
              backgroundColor: Color(0xFFD54A3A),
            ),
          );
      }
      return;
    }
    final fix = result.fix!;

    if (!mounted) return;
    setState(() {
      _currentPosition = LatLng(fix.latitude, fix.longitude);
      _currentAltitude = fix.altitude ?? 0;
    });
    debugPrint(
      '[GPS][nav] fix lat=${fix.latitude.toStringAsFixed(6)} '
      'lng=${fix.longitude.toStringAsFixed(6)} '
      'accuracy=${fix.accuracy.toStringAsFixed(1)}m',
    );

    // Zoom MAX on user immediately for "entering a trail" feel.
    _mapController.move(_currentPosition, 19);

    if (_activeDestination != null) {
      await _refreshRoute(force: true);
    }
  }

  Future<void> _updatePositionSilently() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      if (!mounted) return;

      final newPos = LatLng(position.latitude, position.longitude);

      setState(() {
        if (_hikeStatus == _HikeStatus.inProgress) {
          final distanceMoved = _distance.as(
            LengthUnit.Meter,
            _currentPosition,
            newPos,
          );
          // Only accumulate significant moves (2–100m) to filter GPS jitter
          if (distanceMoved > 2 && distanceMoved < 100) {
            _distanceTraveled += distanceMoved / 1000; // km
          }
        }
        _currentPosition = newPos;
        _currentAltitude = position.altitude;
      });

      final trailProvider = context.read<TrailProvider>();
      final poiProvider = context.read<PoiProvider>();
      final localServiceProvider = context.read<LocalServiceProvider>();

      _refreshNearbyPoints(
        trails: trailProvider.trails,
        pois: poiProvider.pois,
        services: localServiceProvider.services,
      );

      await _refreshRoute();
      _computeOffTrailStatus();
      _checkTargetProximity();
      _maybeAdvancePhaseAfterMove();
    } catch (_) {
      // Ignore temporary GPS failures.
    }
  }

  /// Hybrid routing for the orange guide line:
  ///   • Offline → no API. A direct line to the target is drawn (see [build],
  ///     when [_routePoints] is empty) and guidance is derived locally from the
  ///     trail geometry via [_stepsFromTrailPoints].
  ///   • Online  → OSRM is queried for the real route geometry + turn-by-turn
  ///     steps. Any failure falls back to the offline behaviour.
  Future<void> _refreshRoute({bool force = false}) async {
    if (_activeDestination == null || !mounted) return;
    if (!force && _isRouting) return;

    // No connection → internal computation only (no API call).
    if (_isOffline) {
      _applyOfflineRoute();
      return;
    }

    final destination = _activeDestination!;
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${_currentPosition.longitude},${_currentPosition.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson&steps=true',
    );

    setState(() => _isRouting = true);
    try {
      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('', 408),
          );
      if (response.statusCode != 200) {
        _applyOfflineRoute();
        return;
      }

      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = jsonBody['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        _applyOfflineRoute();
        return;
      }

      final geometry = routes.first['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List?;
      if (coordinates == null || coordinates.isEmpty) {
        _applyOfflineRoute();
        return;
      }

      final points = coordinates
          .whereType<List>()
          .where((point) => point.length >= 2)
          .map(
            (point) => LatLng(
              (point[1] as num).toDouble(),
              (point[0] as num).toDouble(),
            ),
          )
          .toList();

      // Turn-by-turn steps; rewrite the "depart" step with the distance to the
      // first real turn for an actionable instruction.
      final steps = <_RouteStep>[];
      final legs = routes.first['legs'] as List?;
      final rawManeuvers = <Map<String, dynamic>>[];
      if (legs != null && legs.isNotEmpty) {
        final legSteps = legs.first['steps'] as List?;
        if (legSteps != null) {
          for (final step in legSteps) {
            final maneuver = step['maneuver'] as Map<String, dynamic>?;
            if (maneuver == null) continue;
            final loc = maneuver['location'] as List?;
            if (loc == null || loc.length < 2) continue;
            rawManeuvers.add({
              'type': (maneuver['type'] as String?) ?? '',
              'modifier': (maneuver['modifier'] as String?) ?? '',
              'distance': ((step['distance'] as num?) ?? 0).toDouble(),
              'lat': (loc[1] as num).toDouble(),
              'lng': (loc[0] as num).toDouble(),
            });
          }
        }
      }

      String firstDir = '';
      double firstDirDistance = 0;
      for (var i = 0; i < rawManeuvers.length; i++) {
        final t = rawManeuvers[i]['type'] as String;
        if (i == 0 && t == 'depart') {
          firstDirDistance = rawManeuvers[i]['distance'] as double;
          continue;
        }
        if (t == 'turn' || t == 'continue' || t == 'fork' || t == 'new name') {
          firstDir = rawManeuvers[i]['modifier'] as String;
          break;
        }
      }

      for (var i = 0; i < rawManeuvers.length; i++) {
        final m = rawManeuvers[i];
        final type = m['type'] as String;
        var modifier = m['modifier'] as String;
        var distance = m['distance'] as double;
        if (type == 'depart' && firstDir.isNotEmpty) {
          modifier = firstDir;
          distance = firstDirDistance;
        }
        steps.add(
          _RouteStep(
            location: LatLng(m['lat'] as double, m['lng'] as double),
            instruction: _humanInstruction(type, modifier, distance),
            icon: _instructionIcon(type, modifier),
            distanceMeters: distance,
          ),
        );
      }

      if (!mounted) return;
      // OSRM rarely returns useful steps on hiking trails → fall back to steps
      // generated from the trail GeoJSON.
      final finalSteps = steps.length > 1 ? steps : _stepsFromTrailPoints();

      setState(() {
        _routePoints = points;
        _routeSteps = finalSteps;
      });
      _updateCurrentInstruction();
    } catch (_) {
      _applyOfflineRoute();
    } finally {
      if (mounted) {
        setState(() => _isRouting = false);
      }
    }
  }

  /// Internal (offline / fallback) route: a direct line + local trail guidance.
  void _applyOfflineRoute() {
    if (!mounted) return;
    setState(() {
      _routePoints = const [];
      _routeSteps = _stepsFromTrailPoints();
      _isRouting = false;
    });
    _updateCurrentInstruction();
  }

  String _humanInstruction(String type, String modifier, double distance) {
    final dir = switch (modifier) {
      'left' => 'tournez à gauche',
      'right' => 'tournez à droite',
      'sharp left' => 'tournez fortement à gauche',
      'sharp right' => 'tournez fortement à droite',
      'slight left' => 'légère à gauche',
      'slight right' => 'légère à droite',
      'straight' => 'continuez tout droit',
      'uturn' => 'faites demi-tour',
      _ => '',
    };
    // For "depart", inject the distance to the FIRST real turn so the user
    // doesn't read a useless "Démarrez sur le sentier" but rather an action,
    // like: "Après 80 m, tournez à droite".
    if (type == 'depart') {
      final firstMove = dir.isEmpty ? 'continuez tout droit' : dir;
      final meters = distance.round();
      if (meters > 0) {
        return 'Après $meters m, $firstMove';
      }
      return firstMove.substring(0, 1).toUpperCase() + firstMove.substring(1);
    }
    return switch (type) {
      'arrive' => 'Vous êtes arrivé',
      'turn' => dir.isEmpty ? 'Continuez' : dir,
      'continue' => dir.isEmpty ? 'Continuez tout droit' : dir,
      'new name' => 'Continuez',
      'roundabout' => 'Prenez le rond-point',
      'fork' => 'Restez à $modifier',
      _ => dir.isEmpty ? 'Continuez' : dir,
    };
  }

  /// Compass direction (Nord/Nord-Est…) used as a fallback when we don't
  /// know whether to say "à droite" / "à gauche".
  String _compassDirection(double bearing) {
    const labels = [
      'au nord',
      'au nord-est',
      'à l\'est',
      'au sud-est',
      'au sud',
      'au sud-ouest',
      'à l\'ouest',
      'au nord-ouest',
      'au nord',
    ];
    final index = ((bearing % 360) / 45).round();
    return labels[index];
  }

  IconData _instructionIcon(String type, String modifier) {
    if (type == 'arrive') return Icons.flag_rounded;
    if (type == 'depart') return Icons.play_arrow_rounded;
    return switch (modifier) {
      'left' => Icons.turn_left,
      'right' => Icons.turn_right,
      'sharp left' => Icons.turn_sharp_left,
      'sharp right' => Icons.turn_sharp_right,
      'slight left' => Icons.turn_slight_left,
      'slight right' => Icons.turn_slight_right,
      'uturn' => Icons.u_turn_left,
      _ => Icons.straight,
    };
  }

  /// Perpendicular distance from [point] to the polyline [line] in meters.
  /// Uses an equirectangular projection — accurate for hiking-scale distances.
  /// Falls back to vertex distance for degenerate (1-point) lines.
  double _distanceToPolyline(LatLng point, List<LatLng> line) {
    if (line.isEmpty) return double.infinity;
    if (line.length == 1) {
      return _distance.as(LengthUnit.Meter, point, line.first);
    }

    const earthRadius = 6371000.0;
    final lat0 = point.latitude * math.pi / 180.0;
    final cosLat = math.cos(lat0);

    double toX(LatLng p) =>
        p.longitude * math.pi / 180.0 * cosLat * earthRadius;
    double toY(LatLng p) => p.latitude * math.pi / 180.0 * earthRadius;

    final px = toX(point);
    final py = toY(point);

    var minDistSq = double.infinity;
    for (int i = 0; i < line.length - 1; i++) {
      final ax = toX(line[i]);
      final ay = toY(line[i]);
      final bx = toX(line[i + 1]);
      final by = toY(line[i + 1]);

      final dx = bx - ax;
      final dy = by - ay;
      final lenSq = dx * dx + dy * dy;
      double t;
      if (lenSq < 1e-9) {
        t = 0;
      } else {
        t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
        if (t < 0) t = 0;
        if (t > 1) t = 1;
      }
      final cx = ax + t * dx;
      final cy = ay + t * dy;
      final distSq = (px - cx) * (px - cx) + (py - cy) * (py - cy);
      if (distSq < minDistSq) minDistSq = distSq;
    }
    return math.sqrt(minDistSq);
  }

  // Returns the trail point closest to the user's current position.
  // Used to draw a connector line so the route never has visible gaps.
  LatLng _nearestTrailPoint() {
    final pts = _trailPoints;
    if (pts.isEmpty) return _currentPosition;
    LatLng best = pts.first;
    double minM = double.infinity;
    for (final p in pts) {
      final m = _distance.as(LengthUnit.Meter, _currentPosition, p);
      if (m < minM) {
        minM = m;
        best = p;
      }
    }
    return best;
  }

  /// Splits the trail into the part already walked and the part still ahead,
  /// using the trail vertex nearest to the user. The two lists share that
  /// vertex so the green (covered) and violet (remaining) lines join cleanly.
  (List<LatLng>, List<LatLng>) _splitTrailByProgress() {
    final pts = _trailPoints;
    if (pts.length < 2) return (const <LatLng>[], pts);
    int nearestIdx = 0;
    double minM = double.infinity;
    for (int i = 0; i < pts.length; i++) {
      final m = _distance.as(LengthUnit.Meter, _currentPosition, pts[i]);
      if (m < minM) {
        minM = m;
        nearestIdx = i;
      }
    }
    final traveled = pts.sublist(0, nearestIdx + 1);
    final remaining = pts.sublist(nearestIdx);
    return (traveled, remaining);
  }

  // Bearing in degrees [0, 360) from point a to point b
  double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180 / math.pi;
    return (brng + 360) % 360;
  }

  // Detect turns along the trail polyline. Generates a step at each significant
  // bearing change so we always have turn-by-turn instructions, even when OSRM
  // doesn't produce them (common for off-road hiking trails).
  List<_RouteStep> _stepsFromTrailPoints() {
    final pts = _trailPoints;
    if (pts.length < 3) return const [];

    final turns = <_RouteStep>[];
    for (int i = 1; i < pts.length - 1; i++) {
      final b1 = _bearing(pts[i - 1], pts[i]);
      final b2 = _bearing(pts[i], pts[i + 1]);
      var diff = b2 - b1;
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;
      final absDiff = diff.abs();
      // Only consider changes ≥ 25° as real turns
      if (absDiff < 25) continue;

      final modifier = switch (diff) {
        > 100 => 'sharp right',
        > 25 => 'right',
        < -100 => 'sharp left',
        < -25 => 'left',
        _ => 'straight',
      };
      turns.add(
        _RouteStep(
          location: pts[i],
          instruction: _humanInstruction('turn', modifier, 0),
          icon: _instructionIcon('turn', modifier),
          distanceMeters: _distance.as(LengthUnit.Meter, pts.first, pts[i]),
        ),
      );
    }

    // First "depart" instruction: distance and direction to the FIRST turn
    // (or to the trail end if there is no turn).
    final steps = <_RouteStep>[];
    String firstInstruction;
    IconData firstIcon;
    if (turns.isNotEmpty) {
      final firstTurn = turns.first;
      final meters = firstTurn.distanceMeters.round();
      firstInstruction = 'Après $meters m, ${firstTurn.instruction}';
      firstIcon = firstTurn.icon;
    } else {
      final bearing = _bearing(pts.first, pts.last);
      final compass = _compassDirection(bearing);
      final meters = _distance.as(LengthUnit.Meter, pts.first, pts.last).round();
      firstInstruction = 'Continuez $compass sur $meters m';
      firstIcon = Icons.straight;
    }
    steps.add(
      _RouteStep(
        location: pts.first,
        instruction: firstInstruction,
        icon: firstIcon,
        distanceMeters: 0,
      ),
    );
    steps.addAll(turns);
    steps.add(
      _RouteStep(
        location: pts.last,
        instruction: 'Vous êtes arrivé',
        icon: Icons.flag_rounded,
        distanceMeters: 0,
      ),
    );
    return steps;
  }

  void _updateCurrentInstruction() {
    if (_routeSteps.isEmpty) {
      if (_currentInstruction != null) {
        setState(() {
          _currentInstruction = null;
          _currentInstructionDistanceMeters = 0;
        });
      }
      return;
    }

    // Find the next upcoming step:
    //   1. find the closest point on the route to the user (step index)
    //   2. show the FOLLOWING step (the next turn ahead), not the one we
    //      already passed
    int closestIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < _routeSteps.length; i++) {
      final d = _distance.as(
        LengthUnit.Meter,
        _currentPosition,
        _routeSteps[i].location,
      );
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    // If we're within 8m of the closest step, treat it as passed → look ahead.
    int upcomingIdx = closestIdx;
    if (minDist < 8 && closestIdx < _routeSteps.length - 1) {
      upcomingIdx = closestIdx + 1;
    }
    final upcoming = _routeSteps[upcomingIdx];
    final meters =
        _distance.as(LengthUnit.Meter, _currentPosition, upcoming.location).round();

    if (_currentInstruction != upcoming.instruction ||
        _currentInstructionDistanceMeters != meters) {
      setState(() {
        _currentInstruction = upcoming.instruction;
        _currentInstructionDistanceMeters = meters;
      });
    }

    // Voice triggers — speak when 50m, 20m, and 5m before the turn
    if (_hikeStatus == _HikeStatus.inProgress && _voiceEnabled) {
      final id =
          '${upcoming.instruction}-${upcoming.location.latitude.toStringAsFixed(4)}';
      if (meters > 40 && meters <= 55) {
        _speak('Dans $meters mètres, ${upcoming.instruction}.',
            id: '$id-50');
      } else if (meters > 15 && meters <= 25) {
        _speak('Dans $meters mètres, ${upcoming.instruction}.',
            id: '$id-20');
      } else if (meters <= 8) {
        _speak('Maintenant, ${upcoming.instruction}.', id: '$id-now');
      }
    }
  }

  void _refreshNearbyPoints({
    required List<Trail> trails,
    required List<Poi> pois,
    required List<LocalService> services,
  }) {
    final points = <_NavPoint>[];

    for (final trail in trails) {
      if (trail.startLatitude == null || trail.startLongitude == null) continue;
      final point = LatLng(trail.startLatitude!, trail.startLongitude!);
      final km = _distance.as(LengthUnit.Kilometer, _currentPosition, point);
      if (km > 5) continue;
      points.add(
        _NavPoint(
          id: 'trail_${trail.id}',
          name: trail.name,
          subtitle: 'Trail nearby',
          point: point,
          icon: Icons.hiking,
          color: Colors.green,
          distanceKm: km,
        ),
      );
    }

    for (final poi in pois) {
      final point = LatLng(poi.latitude, poi.longitude);
      final km = _distance.as(LengthUnit.Kilometer, _currentPosition, point);
      if (km > 5) continue;
      points.add(
        _NavPoint(
          id: 'poi_${poi.id}',
          name: poi.name,
          subtitle: 'Rare point nearby',
          point: point,
          icon: Icons.place,
          color: const Color(0xFF212121),
          distanceKm: km,
        ),
      );
    }

    for (final service in services) {
      if (service.latitude == null || service.longitude == null) continue;
      final point = LatLng(service.latitude!, service.longitude!);
      final km = _distance.as(LengthUnit.Kilometer, _currentPosition, point);
      if (km > 5) continue;
      points.add(
        _NavPoint(
          id: 'service_${service.id}',
          name: service.name,
          subtitle: 'Local service nearby',
          point: point,
          icon: Icons.storefront,
          color: const Color(0xFF1E9A35),
          distanceKm: km,
        ),
      );
    }

    points.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    if (!mounted) return;
    setState(() {
      _nearbyPoints = points;
      _featuredPoint = points.isEmpty ? null : points.first;
      _activeDestination ??= _featuredPoint?.point;
      _activeDestinationLabel ??= _featuredPoint?.name;
    });
  }

  // Alert when more than 5 m off the reference path; clear back at 3 m to
  // avoid flapping with GPS jitter (hysteresis).
  static const double _offTrailEnterMeters = 5;
  static const double _offTrailExitMeters = 3;

  /// Returns the reference polyline used to decide if the user is off-trail.
  /// - In [_NavPhase.onTrail]: the official trail GeoJSON polyline.
  /// - In [_NavPhase.goToStart] or [_NavPhase.toPoi]: the OSRM route.
  List<LatLng> _offTrailReferencePoints() {
    switch (_navPhase) {
      case _NavPhase.onTrail:
        return _trailPoints;
      case _NavPhase.goToStart:
      case _NavPhase.toPoi:
        return _routePoints;
    }
  }

  void _computeOffTrailStatus() {
    // The user can switch the off-trail alert off completely.
    if (_offTrailDisabled) {
      if (_offTrailAlert) _clearOffTrailAlert();
      return;
    }
    // Off-trail is only meaningful while the hike is actually in progress.
    if (_hikeStatus != _HikeStatus.inProgress) {
      if (_offTrailAlert) _clearOffTrailAlert();
      return;
    }

    final referencePoints = _offTrailReferencePoints();
    if (referencePoints.length < 2) {
      if (_offTrailAlert) _clearOffTrailAlert();
      return;
    }

    final distMeters = _distanceToPolyline(_currentPosition, referencePoints);

    if (!mounted) return;

    final wasOffTrail = _offTrailAlert;
    final isOffTrail = wasOffTrail
        ? distMeters > _offTrailExitMeters
        : distMeters > _offTrailEnterMeters;

    if (isOffTrail != wasOffTrail || _offTrailDistance != distMeters) {
      setState(() {
        _offTrailAlert = isOffTrail;
        _offTrailDistance = distMeters;
      });
    }

    if (isOffTrail && !wasOffTrail) {
      _startOffTrailBuzz();
      if (!_offTrailMuted) {
        final spoken = _navPhase == _NavPhase.onTrail
            ? 'Vous êtes hors du sentier. Appuyez sur Recalculer pour vous réorienter.'
            : 'Vous avez quitté l\'itinéraire. Appuyez sur Recalculer.';
        _speak(spoken, id: 'off_trail_alert');
      }
    } else if (!isOffTrail && wasOffTrail) {
      _stopOffTrailBuzz();
    }
  }

  /// Proximity alerts toward the PRECISE point the user must reach:
  ///  - a trail's START point (the trailhead) — never the end point, or
  ///  - the POI / service / annuaire destination point.
  ///
  /// Fires a one-shot "approaching" alert at [_approachMeters] (7 m) and a
  /// "Vous êtes là" arrival announcement at [_reachedStartMeters] (5 m).
  void _checkTargetProximity() {
    final bool isTrail = widget.trail != null;
    if (isTrail) {
      // Only while actively walking toward the start of the trail.
      if (_hikeStatus != _HikeStatus.inProgress) return;
      if (_navPhase != _NavPhase.goToStart) return;
    } else if (_activeDestination == null) {
      return;
    }

    final LatLng? target = isTrail ? _trailStartPoint : _activeDestination;
    if (target == null) return;

    final meters = _distance.as(LengthUnit.Meter, _currentPosition, target);

    // Approaching alert at 7 m.
    if (meters <= _approachMeters && !_approachAnnounced) {
      _approachAnnounced = true;
      HapticFeedback.lightImpact();
      _speak(
        isTrail
            ? 'Vous approchez du point de départ. Plus que ${meters.round()} mètres.'
            : 'Vous approchez de votre destination. Plus que ${meters.round()} mètres.',
        id: 'approach_target',
      );
    }

    // Arrival "Vous êtes là" at 5 m.
    if (meters <= _reachedStartMeters && !_arrivedAnnounced) {
      _arrivedAnnounced = true;
      HapticFeedback.mediumImpact();
      _speak(
        isTrail
            ? 'Vous êtes là ! Vous êtes au point de départ du sentier. Suivez le tracé.'
            : 'Vous êtes là ! Vous êtes arrivé à ${_activeDestinationLabel ?? 'destination'}.',
        id: 'arrived_target',
      );
    }
  }

  /// Advances `_navPhase` from goToStart → onTrail once the user is within
  /// [_reachedStartMeters] of the trail start point. The "Vous êtes là"
  /// announcement is handled by [_checkTargetProximity].
  void _maybeAdvancePhaseAfterMove() {
    if (_navPhase != _NavPhase.goToStart) return;
    final start = _trailStartPoint;
    if (start == null) return;
    final meters = _distance.as(LengthUnit.Meter, _currentPosition, start);
    if (meters > _reachedStartMeters) return;

    setState(() {
      _navPhase = _NavPhase.onTrail;
      _activeDestination = _trailEndPoint ?? start;
      _activeDestinationLabel = widget.trail?.name ?? _activeDestinationLabel;
      // Clear the OSRM "go-to-start" route — the trail polyline takes over.
      _routePoints = [];
    });
  }

  void _clearOffTrailAlert() {
    setState(() {
      _offTrailAlert = false;
      _offTrailDistance = 0;
      // Once back on the trail, the orange recovery route is no longer
      // useful — drop it so the user sees the regular trail polyline.
      if (_navPhase == _NavPhase.onTrail) {
        _routePoints = [];
      }
    });
    _stopOffTrailBuzz();
  }

  void _startOffTrailBuzz() {
    _offTrailBuzzTimer?.cancel();
    if (_offTrailMuted) return;
    // Quick double-tap haptic every ~1.2 s while off-trail.
    HapticFeedback.heavyImpact();
    _offTrailBuzzTimer = Timer.periodic(
      const Duration(milliseconds: 1200),
      (_) {
        if (!mounted || !_offTrailAlert || _offTrailMuted) return;
        HapticFeedback.heavyImpact();
        Future.delayed(
          const Duration(milliseconds: 180),
          () {
            if (mounted && _offTrailAlert && !_offTrailMuted) {
              HapticFeedback.heavyImpact();
            }
          },
        );
      },
    );
  }

  void _stopOffTrailBuzz() {
    _offTrailBuzzTimer?.cancel();
    _offTrailBuzzTimer = null;
  }

  void _toggleOffTrailMute() {
    setState(() => _offTrailMuted = !_offTrailMuted);
    if (_offTrailMuted) {
      _stopOffTrailBuzz();
    } else if (_offTrailAlert) {
      _startOffTrailBuzz();
    }
  }

  /// Turns the off-trail alert fully off (banner + vibration + voice) until the
  /// user re-enables it from the action column. Shows a quick hint on how to
  /// bring it back.
  void _disableOffTrailAlert() {
    setState(() => _offTrailDisabled = true);
    _clearOffTrailAlert();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2E7D32),
          content: const Text('Alerte hors-sentier désactivée'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Réactiver',
            textColor: Colors.white,
            onPressed: _toggleOffTrailDetection,
          ),
        ),
      );
  }

  /// Toggles off-trail detection on/off. Re-enabling re-evaluates immediately so
  /// a current deviation re-appears right away.
  void _toggleOffTrailDetection() {
    final willDisable = !_offTrailDisabled;
    setState(() => _offTrailDisabled = willDisable);
    if (willDisable) {
      _clearOffTrailAlert();
    } else {
      _computeOffTrailStatus();
    }
  }

  void _selectDestination(_NavPoint point) {
    setState(() {
      _activeDestination = point.point;
      _activeDestinationLabel = point.name;
      _routePoints = [];
      _featuredPoint = point;
    });
    _mapController.move(point.point, 15);
    _refreshRoute(force: true);
  }

  void _cycleMapStyle() {
    // Toggle between the two shared styles; the notifier keeps every map
    // (mini-map / big map) in sync with the choice.
    appMapStyle.value = appMapStyle.value.next;
  }

  Widget _navIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Material(
      color: active ? const Color(0xFFFF8C42) : const Color(0xFF2E7D32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  IconData _findUpcomingStepIcon() {
    if (_routeSteps.isEmpty) return Icons.straight;
    _RouteStep? upcoming;
    double minDist = double.infinity;
    for (final step in _routeSteps) {
      final d =
          _distance.as(LengthUnit.Meter, _currentPosition, step.location);
      if (d < minDist && d < 500) {
        minDist = d;
        upcoming = step;
      }
    }
    return upcoming?.icon ?? Icons.straight;
  }

  void _toggleVoice() {
    setState(() => _voiceEnabled = !_voiceEnabled);
    if (!_voiceEnabled) {
      _tts.stop();
    }
  }

  Future<void> _handleReroute() async {
    HapticFeedback.lightImpact();

    // Immediately dismiss the off-trail banner + stop the vibration loop.
    // It will reappear automatically on the next GPS update if the user is
    // still off the freshly-computed route.
    if (_offTrailAlert) _clearOffTrailAlert();

    // Pick the target depending on the current phase:
    // - onTrail   → route back to the nearest point on the trail polyline
    // - goToStart → re-route to the trail start
    // - toPoi     → re-route to the active POI/service destination
    LatLng? target;
    String? targetLabel;
    switch (_navPhase) {
      case _NavPhase.onTrail:
        if (_trailPoints.isNotEmpty) {
          target = _nearestTrailPoint();
          targetLabel = 'Retour au sentier';
        }
        break;
      case _NavPhase.goToStart:
        target = _trailStartPoint ?? _activeDestination;
        targetLabel = _activeDestinationLabel;
        break;
      case _NavPhase.toPoi:
        target = _activeDestination;
        targetLabel = _activeDestinationLabel;
        break;
    }

    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune destination active.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Update destination so the offline direct line + local guidance are
    // recomputed toward it.
    setState(() {
      _activeDestination = target;
      if (targetLabel != null) _activeDestinationLabel = targetLabel;
      _routePoints = [];
      _routeSteps = [];
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Recalcul du tracé...'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await _refreshRoute(force: true);

    if (!mounted) return;
    // Offline reorientation always succeeds (direct line + local guidance).
    _speak(
      'Réorientation effectuée. Suivez la direction indiquée.',
      id: 'reroute_done',
    );
  }

  @override
  Widget build(BuildContext context) {
    final destination = _activeDestination;
    final hasDestination = destination != null;
    final destinationKm = hasDestination
        ? _distance.as(LengthUnit.Kilometer, _currentPosition, destination)
        : 0.0;

    // Trail start / end points (separate from the active destination)
    final trailStart = _trailStartPoint;
    final trailEnd = _trailEndPoint;

    // While walking the trail, split it into the part already covered (green)
    // and the part still ahead (violet), based on the user's position.
    final bool showTrailProgress =
        _navPhase == _NavPhase.onTrail && _trailPoints.length >= 2;
    final (List<LatLng> traveledTrail, List<LatLng> remainingTrail) =
        showTrailProgress
            ? _splitTrailByProgress()
            : (const <LatLng>[], _trailPoints);

    return Scaffold(
      appBar: _isFullScreen ? null : const EcoPageHeader(title: 'Navigation & SOS'),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: destination ?? _currentPosition,
              initialZoom: 14,
              minZoom: 3,
              // Allow deeper zoom than the tiles provide (overzoom): the last
              // available tiles are upscaled past the native max.
              maxZoom: 22,
            ),
            children: [
              TileLayer(
                // Always use the selected style; the tile provider serves it
                // from the matching offline cache (standard or satellite).
                urlTemplate: appMapStyle.value.urlTemplate,
                userAgentPackageName: 'com.ecoguide.app',
                // Real tiles up to 19; levels 20-22 are upscaled so the user
                // can keep zooming even where no higher-res data exists.
                maxNativeZoom: 19,
                maxZoom: 22,
                tileProvider: LocalFirstTileProvider(
                  service: _mapOfflineService,
                ),
                reset: _tileResetStream.stream,
              ),
              PolylineLayer(
                polylines: [
                  // Trail GeoJSON (fixed path) — drawn underneath everything
                  // so OSRM routes (go-to-start / recovery) can sit on top.
                  // Before starting the trail: the whole path, dimmed violet.
                  if (_trailPoints.isNotEmpty && !showTrailProgress)
                    Polyline(
                      points: _trailPoints,
                      strokeWidth: 6,
                      color: Colors.deepPurpleAccent.withValues(alpha: 0.55),
                    ),
                  // While walking: part still ahead in violet…
                  if (showTrailProgress && remainingTrail.length >= 2)
                    Polyline(
                      points: remainingTrail,
                      strokeWidth: 6,
                      color: Colors.deepPurpleAccent,
                    ),
                  // …and the part already covered in green, drawn on top.
                  if (showTrailProgress && traveledTrail.length >= 2)
                    Polyline(
                      points: traveledTrail,
                      strokeWidth: 6,
                      color: const Color(0xFF22B53A),
                    ),
                  // Orange guide line: the real OSRM route when online, or a
                  // direct line when offline (fallback). Hidden via the
                  // "hide link" button. Also shown during on-trail recovery
                  // when a route was fetched.
                  if (hasDestination &&
                      !_hideStartLink &&
                      (_navPhase != _NavPhase.onTrail ||
                          _routePoints.isNotEmpty))
                    Polyline(
                      points: _routePoints.isNotEmpty
                          ? [_currentPosition, ..._routePoints, destination]
                          : [_currentPosition, destination],
                      strokeWidth: 5,
                      color: const Color(0xFFFF8C42),
                    ),
                  // Subtle dotted connector: user → nearest trail point.
                  // Only useful when ON-trail with a small drift so the user
                  // sees where the trail is. Hidden during goToStart to avoid
                  // a confusing double-line, and via the "hide link" button.
                  if (_trailPoints.isNotEmpty &&
                      !_hideStartLink &&
                      _navPhase == _NavPhase.onTrail &&
                      _routePoints.isEmpty)
                    Polyline(
                      points: [
                        _currentPosition,
                        _nearestTrailPoint(),
                      ],
                      strokeWidth: 3,
                      color: _offTrailAlert
                          ? const Color(0xFFE53935)
                          : const Color(0xFF1A73E8),
                      pattern: const StrokePattern.dotted(),
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentPosition,
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer accuracy halo
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                        ),
                        // Inner blue dot
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A73E8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        // Direction cone — rotates with phone heading
                        Transform.rotate(
                          angle: _heading * 3.1415926535 / 180,
                          child: const Padding(
                            padding: EdgeInsets.only(bottom: 28),
                            child: Icon(
                              Icons.arrow_drop_up,
                              color: Color(0xFF1A73E8),
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Trail start marker (separate from destination)
                  if (trailStart != null)
                    Marker(
                      point: trailStart,
                      width: 38,
                      height: 38,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E7A23),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  // Trail end marker
                  if (trailEnd != null)
                    Marker(
                      point: trailEnd,
                      width: 38,
                      height: 38,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.flag,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  // Active destination (POI / service / custom point) — only when not a trail end
                  if (hasDestination &&
                      (trailEnd == null ||
                          _distance.as(LengthUnit.Meter,
                                  destination, trailEnd) > 30))
                    Marker(
                      point: destination,
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E9A35),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ..._nearbyPoints.map(
                    (point) => Marker(
                      point: point.point,
                      width: 28,
                      height: 28,
                      child: GestureDetector(
                        onTap: () => _selectDestination(point),
                        child: CircleAvatar(
                          backgroundColor: point.color,
                          child: Icon(
                            point.icon,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (hasDestination)
            Positioned(
              top: 8,
              left: 10,
              // Leave room on the right for the vertical action column
              // (fullscreen / layers / …) so they never overlap the banner.
              right: 64,
              child: _buildInstructionBanner(destinationKm),
            ),
          if (_offTrailAlert)
            Positioned(
              // Sit below the instruction banner and leave room on the right
              // for the vertical action column (zoom / layers / my-location).
              top: hasDestination ? 195 : 16,
              left: 12,
              right: 64,
              child: _buildOffTrailBanner(),
            ),
          Positioned(
            right: 12,
            bottom: _isFullScreen ? 24 : 230,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _navIconButton(
                  icon: _isFullScreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  onTap: () =>
                      setState(() => _isFullScreen = !_isFullScreen),
                ),
                const SizedBox(height: 6),
                _navIconButton(
                  icon: Icons.layers,
                  onTap: _cycleMapStyle,
                ),
                const SizedBox(height: 6),
                // Hide / show the link between current position and the
                // start/target (the orange guide line + dotted connector).
                _navIconButton(
                  icon: _hideStartLink
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  active: _hideStartLink,
                  onTap: () =>
                      setState(() => _hideStartLink = !_hideStartLink),
                ),
                const SizedBox(height: 6),
                // Off-trail alert on/off — when disabled the button turns orange
                // so the user can spot (and re-enable) it at a glance.
                _navIconButton(
                  icon: _offTrailDisabled
                      ? Icons.notifications_off_rounded
                      : Icons.notifications_active_rounded,
                  active: _offTrailDisabled,
                  onTap: _toggleOffTrailDetection,
                ),
                const SizedBox(height: 6),
                _navIconButton(
                  icon: Icons.explore,
                  onTap: () => _mapController.rotate(0),
                ),
                const SizedBox(height: 6),
                _navIconButton(
                  icon: Icons.my_location,
                  onTap: () => _detectUserPosition(feedback: true),
                ),
                const SizedBox(height: 6),
                _navIconButton(
                  icon: Icons.add,
                  onTap: () {
                    final z =
                        (_mapController.camera.zoom + 1).clamp(3.0, 19.0);
                    _mapController.move(_mapController.camera.center, z);
                  },
                ),
                const SizedBox(height: 6),
                _navIconButton(
                  icon: Icons.remove,
                  onTap: () {
                    final z =
                        (_mapController.camera.zoom - 1).clamp(3.0, 19.0);
                    _mapController.move(_mapController.camera.center, z);
                  },
                ),
              ],
            ),
          ),
          // Floating SOS button — always reachable, including in full-screen
          // mode. (When NOT full-screen and the hike hasn't started yet, the
          // SOS button is already visible inline next to "Commencer le Trail",
          // so we skip the floating one to avoid a duplicate.)
          if (_isFullScreen || _hikeStatus != _HikeStatus.notStarted)
            Positioned(
              left: 14,
              bottom: _isFullScreen
                  ? 24 + MediaQuery.of(context).padding.bottom
                  : 240,
              child: _buildFloatingSosButton(compact: true),
            ),
          if (!_isFullScreen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomStatsPanel(destinationKm),
            ),
          if (_isLoading || _isRouting)
            const Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildOffTrailBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meters = _offTrailDistance.round();
    final distanceText = meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '$meters m';
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF4A1F1B), Color(0xFF2E1310)]
              : const [Color(0xFFFFE5DD), Color(0xFFFFD4C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE53935).withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFE53935),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hors du sentier',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFFF8A80)
                        : const Color(0xFFB12F22),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1.1,
                  ),
                ),
                Text(
                  'À $distanceText du tracé',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.2,
                    color: isDark
                        ? const Color(0xFFFFB4A8)
                        : const Color(0xFFB12F22),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _offTrailIconButton(
            tooltip: _offTrailMuted
                ? 'Réactiver la vibration'
                : 'Couper la vibration',
            icon: _offTrailMuted
                ? Icons.vibration
                : Icons.do_not_disturb_on_total_silence,
            onTap: _toggleOffTrailMute,
          ),
          const SizedBox(width: 4),
          _offTrailIconButton(
            tooltip: 'Recalculer',
            icon: Icons.refresh_rounded,
            primary: true,
            onTap: _handleReroute,
          ),
          const SizedBox(width: 4),
          _offTrailIconButton(
            tooltip: 'Désactiver l\'alerte',
            icon: Icons.close_rounded,
            onTap: _disableOffTrailAlert,
          ),
        ],
      ),
    );
  }

  Widget _offTrailIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool primary = false,
  }) {
    final color = primary ? const Color(0xFFE53935) : Colors.white;
    final iconColor = primary ? Colors.white : const Color(0xFFE53935);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: primary ? 2 : 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, color: iconColor, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionBanner(double destinationKm) {
    final hasInstruction =
        _currentInstruction != null && _currentInstruction!.isNotEmpty;
    final meters = _currentInstructionDistanceMeters;
    final manoeuvreIcon =
        _routeSteps.isNotEmpty ? _findUpcomingStepIcon() : Icons.straight;
    final isClose = meters > 0 && meters <= 20;

    final destLabel = _activeDestinationLabel ?? 'destination';
    final remainStr = destinationKm < 1
        ? '${(destinationKm * 1000).round()} m'
        : '${destinationKm.toStringAsFixed(1)} km';

    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isClose
                ? const [Color(0xFFFF8C42), Color(0xFFE9591F)]
                : const [Color(0xFF1F8A2F), Color(0xFF0E7A23)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(manoeuvreIcon, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasInstruction && meters > 0)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$meters',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 30,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'm',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      else
                        const Text(
                          'En route',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        hasInstruction
                            ? _currentInstruction!
                            : 'Vers $destLabel',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _toggleVoice,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _voiceEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
            const SizedBox(height: 8),
            Row(
              children: [
                _bannerStat(Icons.flag_outlined, 'Restant', remainStr),
                _bannerDivider(),
                _bannerStat(
                  Icons.directions_walk,
                  'Vers',
                  destLabel.length > 14
                      ? '${destLabel.substring(0, 12)}…'
                      : destLabel,
                ),
                _bannerDivider(),
                _bannerStat(
                  Icons.timer_outlined,
                  'ETA',
                  _formatEta(destinationKm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerStat(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white70, size: 13),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerDivider() {
    return Container(
      width: 1,
      height: 26,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  /// Estimates arrival time assuming ~4.5 km/h hiking pace.
  String _formatEta(double remainingKm) {
    if (remainingKm <= 0) return '—';
    const paceKmh = 4.5;
    final minutes = (remainingKm / paceKmh * 60).round();
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  Widget _buildBottomStatsPanel(double destinationKm) {
    if (_hikeStatus == _HikeStatus.notStarted) {
      return Container(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          22 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            if (widget.trail != null) ...[
              Text(
                widget.trail!.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _trailChip(Icons.straighten, widget.trail!.distanceText),
                  const SizedBox(width: 8),
                  _trailChip(Icons.timer_outlined, widget.trail!.durationText),
                  const SizedBox(width: 8),
                  _trailChip(Icons.terrain, widget.trail!.difficulty),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22B53A), Color(0xFF0E7A23)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22B53A)
                              .withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _startHike,
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_circle_fill,
                                  color: Colors.white, size: 28),
                              SizedBox(width: 10),
                              Text(
                                'Commencer le Trail',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildFloatingSosButton(),
              ],
            ),
          ],
        ),
      );
    }

    final h = _elapsedTime.inHours;
    final m = (_elapsedTime.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsedTime.inSeconds % 60).toString().padLeft(2, '0');
    final durationStr = h > 0 ? '${h}h ${m}m' : '${m}m ${s}s';

    final pace = _distanceTraveled > 0 && _elapsedTime.inSeconds > 0
        ? (_distanceTraveled / (_elapsedTime.inSeconds / 3600)).toStringAsFixed(1)
        : '—';

    final altStr = '${_currentAltitude.round()} m';

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : const Color(0xFFDDD7CE),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 3,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 10),
          // Single row: temps · parcouru · vitesse · altitude.
          // "Restant" is intentionally omitted here because it's already shown
          // prominently in the top instruction banner.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricItem(durationStr, 'Temps', Icons.timer_outlined),
              _metricItem(
                '${_distanceTraveled.toStringAsFixed(2)} km',
                'Parcouru',
                Icons.straighten,
              ),
              _metricItem('$pace km/h', 'Vitesse', Icons.speed),
              _metricItem(altStr, 'Altitude', Icons.terrain_outlined),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (_hikeStatus == _HikeStatus.inProgress)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _pauseHike,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6E431F),
                    ),
                    icon: const Icon(Icons.pause, size: 16),
                    label: const Text('Pause'),
                  ),
                )
              else
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _resumeHike,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD68227),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Reprendre'),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _finishHike,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                  ),
                  icon: const Icon(Icons.flag_rounded, size: 16),
                  label: const Text('Terminer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricItem(String value, String label, [IconData? icon]) {
    final dimColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 14, color: dimColor),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: dimColor),
        ),
      ],
    );
  }

  Widget _trailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF22B53A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0E7A23)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0E7A23),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingSosButton({bool compact = false}) {
    final size = compact ? 54.0 : 58.0;
    final radius = compact ? 27.0 : 16.0;
    return GestureDetector(
      onTap: _openSosScreen,
      onLongPress: _openSosScreen,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE63946), Color(0xFFC62828)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE63946).withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white, width: 2.5),
        ),
        child: const Center(
          child: Text(
            'SOS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  void _openSosScreen() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SosScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}

class _NavPoint {
  final String id;
  final String name;
  final String subtitle;
  final LatLng point;
  final IconData icon;
  final Color color;
  final double distanceKm;

  _NavPoint({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.point,
    required this.icon,
    required this.color,
    required this.distanceKm,
  });
}

class _RouteStep {
  final LatLng location;
  final String instruction;
  final IconData icon;
  final double distanceMeters;

  const _RouteStep({
    required this.location,
    required this.instruction,
    required this.icon,
    required this.distanceMeters,
  });
}


enum _HikeStatus { notStarted, inProgress, paused, finished }

/// Phase of the navigation, drives both the rendered route and the
/// off-trail reference polyline.
/// - [toPoi]      : navigating to a POI / service (no trail bound to widget)
/// - [goToStart]  : trail bound but user is far from the start; we route
///                  the user to the start using OSRM
/// - [onTrail]    : user is on the official trail polyline; we follow it
enum _NavPhase { toPoi, goToStart, onTrail }
