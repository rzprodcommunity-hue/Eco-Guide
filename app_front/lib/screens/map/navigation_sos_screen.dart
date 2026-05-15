import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../../services/map_offline_service.dart';
import '../../core/widgets/eco_page_header.dart';
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

  _MapVisualStyle _mapStyle = _MapVisualStyle.satellite;

  List<_NavPoint> _nearbyPoints = [];
  _NavPoint? _featuredPoint;

  _HikeStatus _hikeStatus = _HikeStatus.notStarted;
  bool _isFullScreen = false;
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
  DateTime? _lastOffTrailVibration;
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
    _tileResetStream = StreamController<void>();
    _mapOfflineService.initialize();
    _activeDestination = widget.destination;
    _activeDestinationLabel = widget.destinationLabel;

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
      _detectUserPosition();
      _startGpsTracking();
      _fitToTrailBounds();
      // Entry animation: brief overview, then zoom to user with max detail
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      _animateToUserMaxZoom();
    });
  }

  void _animateToUserMaxZoom() {
    // Smooth Google-Maps-style entry: zoom into user position at max detail
    _mapController.move(_currentPosition, 17.5);
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _positionStream?.cancel();
    _compassStream?.cancel();
    _stopwatchTimer?.cancel();
    _tts.stop();
    _tileResetStream.close();
    super.dispose();
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
      if (metersToStart > 20) {
        await _showAwayFromStartAlert(metersToStart, startPoint);
        if (!mounted) return;
        // Reroute: from current position → start → end (trail acts as second leg)
        _activeDestination = startPoint;
        _activeDestinationLabel =
            '${trail?.name ?? 'Sentier'} (point de départ)';
        await _refreshRoute(force: true);
        if (!mounted) return;
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
        icon: const Icon(Icons.location_off, color: Color(0xFFE65245), size: 42),
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
    try {
      final apiClient = context.read<ApiClient>();
      final activityService = ActivityService(apiClient);
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

  Future<void> _detectUserPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );

    if (!mounted) return;
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    _mapController.move(_activeDestination ?? _currentPosition, 14);

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
    } catch (_) {
      // Ignore temporary GPS failures.
    }
  }

  Future<void> _refreshRoute({bool force = false}) async {
    if (_activeDestination == null || !mounted) return;

    if (!force && _isRouting) return;

    final destination = _activeDestination!;
    // Note: project-osrm.org public API only supports /driving/ profile.
    // /foot/ would return 400 Bad Request and leave the route empty.
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
      if (response.statusCode != 200) return;

      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = jsonBody['routes'] as List?;
      if (routes == null || routes.isEmpty) return;

      final geometry = routes.first['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List?;
      if (coordinates == null || coordinates.isEmpty) return;

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

      // Parse turn-by-turn steps from OSRM
      final steps = <_RouteStep>[];
      final legs = routes.first['legs'] as List?;
      if (legs != null && legs.isNotEmpty) {
        final legSteps = legs.first['steps'] as List?;
        if (legSteps != null) {
          for (final step in legSteps) {
            final maneuver = step['maneuver'] as Map<String, dynamic>?;
            if (maneuver == null) continue;
            final loc = maneuver['location'] as List?;
            if (loc == null || loc.length < 2) continue;
            final type = (maneuver['type'] as String?) ?? '';
            final modifier = (maneuver['modifier'] as String?) ?? '';
            final distance = ((step['distance'] as num?) ?? 0).toDouble();
            steps.add(
              _RouteStep(
                location: LatLng(
                  (loc[1] as num).toDouble(),
                  (loc[0] as num).toDouble(),
                ),
                instruction: _humanInstruction(type, modifier, distance),
                icon: _instructionIcon(type, modifier),
                distanceMeters: distance,
              ),
            );
          }
        }
      }

      if (!mounted) return;
      // If OSRM didn't return useful steps (which often happens on hiking
      // trails), generate them from the trail GeoJSON using bearing math.
      final finalSteps = steps.length > 1 ? steps : _stepsFromTrailPoints();

      setState(() {
        _routePoints = points;
        _routeSteps = finalSteps;
      });
      _updateCurrentInstruction();
    } catch (_) {
      // Fallback is handled by direct line when route data is missing.
    } finally {
      if (mounted) {
        setState(() => _isRouting = false);
      }
    }
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
    return switch (type) {
      'depart' => 'Démarrez sur le sentier',
      'arrive' => 'Vous êtes arrivé',
      'turn' => dir.isEmpty ? 'Continuez' : dir,
      'continue' => dir.isEmpty ? 'Continuez tout droit' : dir,
      'new name' => 'Continuez',
      'roundabout' => 'Prenez le rond-point',
      'fork' => 'Restez à $modifier',
      _ => dir.isEmpty ? 'Continuez' : dir,
    };
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

    final steps = <_RouteStep>[];
    steps.add(
      _RouteStep(
        location: pts.first,
        instruction: 'Démarrez sur le sentier',
        icon: Icons.play_arrow_rounded,
        distanceMeters: 0,
      ),
    );

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
      steps.add(
        _RouteStep(
          location: pts[i],
          instruction: _humanInstruction('turn', modifier, 0),
          icon: _instructionIcon('turn', modifier),
          distanceMeters: 0,
        ),
      );
    }

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

  void _computeOffTrailStatus() {
    final referencePoints =
        _trailPoints.isNotEmpty ? _trailPoints : _routePoints;

    if (referencePoints.length < 2) {
      if (_offTrailAlert) setState(() => _offTrailAlert = false);
      return;
    }

    var minMeters = double.infinity;
    for (final point in referencePoints) {
      final d = _distance.as(LengthUnit.Meter, _currentPosition, point);
      if (d < minMeters) minMeters = d;
    }

    if (!mounted) return;
    // Tighter threshold during hike (10m); wider when not started (50m)
    final threshold = _hikeStatus == _HikeStatus.inProgress ? 10.0 : 50.0;
    final wasOffTrail = _offTrailAlert;
    final isOffTrail = minMeters > threshold;

    if (isOffTrail != wasOffTrail) {
      setState(() => _offTrailAlert = isOffTrail);
    }

    // Trigger vibration + voice when newly off-trail (debounce 20s)
    if (isOffTrail && _hikeStatus == _HikeStatus.inProgress) {
      final now = DateTime.now();
      if (_lastOffTrailVibration == null ||
          now.difference(_lastOffTrailVibration!) >
              const Duration(seconds: 20)) {
        _lastOffTrailVibration = now;
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 200),
            () => HapticFeedback.heavyImpact());
        Future.delayed(const Duration(milliseconds: 400),
            () => HapticFeedback.heavyImpact());
        _speak(
          'Attention. Vous êtes hors du sentier. Appuyez sur réorienter pour recalculer.',
          id: 'off_trail_alert',
        );
      }
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
    final styles = _MapVisualStyle.values;
    final currentIndex = styles.indexOf(_mapStyle);
    final nextIndex = (currentIndex + 1) % styles.length;
    setState(() => _mapStyle = styles[nextIndex]);
  }

  Widget _navIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF2E7D32),
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
    if (_activeDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune destination active.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Clear visual feedback so the user sees the recompute
    setState(() => _routePoints = []);
    HapticFeedback.lightImpact();

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
            Text('Recalcul de l\'itinéraire...'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await _refreshRoute(force: true);

    if (!mounted) return;
    if (_routePoints.isNotEmpty) {
      _speak('Itinéraire mis à jour.', id: 'reroute_done');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de calculer l\'itinéraire. Réessayez.'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
    }
  }

  List<_NavPoint> get _nearbyWithin20m {
    return _nearbyPoints.where((p) => p.distanceKm * 1000 <= 20).toList();
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

    return Scaffold(
      appBar: _isFullScreen ? null : const EcoPageHeader(title: 'Navigation & SOS'),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: destination ?? _currentPosition,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: _mapStyle.urlTemplate,
                userAgentPackageName: 'com.ecoguide.app',
                tileProvider: LocalFirstTileProvider(
                  service: _mapOfflineService,
                ),
                reset: _tileResetStream.stream,
              ),
              PolylineLayer(
                polylines: [
                  // Connector: user → nearest trail point (dotted blue)
                  // Always drawn so the path looks continuous, even when
                  // no road exists between user and trail.
                  if (_trailPoints.isNotEmpty)
                    Polyline(
                      points: [
                        _currentPosition,
                        _nearestTrailPoint(),
                      ],
                      strokeWidth: 4,
                      color: const Color(0xFF1A73E8),
                      pattern: const StrokePattern.dotted(),
                    ),
                  // Trail GeoJSON (fixed path) — thick purple
                  if (_trailPoints.isNotEmpty)
                    Polyline(
                      points: _trailPoints,
                      strokeWidth: 6,
                      color: Colors.deepPurpleAccent,
                    ),
                  // Live OSRM route from user → destination — recomputable
                  // Only shown when destination is NOT on the trail (POI/service).
                  if (hasDestination && _trailPoints.isEmpty)
                    Polyline(
                      points: _routePoints.isNotEmpty
                          ? [
                              _currentPosition,
                              ..._routePoints,
                              destination,
                            ]
                          : [_currentPosition, destination],
                      strokeWidth: 4,
                      color: const Color(0xFF8E44AD),
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
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _routeSteps.isNotEmpty
                          ? _findUpcomingStepIcon()
                          : Icons.straight,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentInstruction != null &&
                                    _currentInstructionDistanceMeters > 0
                                ? '$_currentInstructionDistanceMeters m'
                                : (destinationKm < 1
                                    ? '${(destinationKm * 1000).round()}m'
                                    : '${destinationKm.toStringAsFixed(1)} km'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            _currentInstruction ??
                                'Vers ${_activeDestinationLabel ?? 'destination'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleVoice,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _voiceEnabled
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_offTrailAlert)
            Positioned(
              top: hasDestination ? 96 : 14,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF3D201E)
                      : const Color(0xFFFDF3F3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.red.withValues(alpha: 0.5)
                        : const Color(0xFFE97C74),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFE65245),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Off-Trail Alert',
                            style: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.redAccent
                                  : const Color(0xFFD64A3A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'You are away from the path.',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.redAccent.withValues(alpha: 0.8)
                                  : const Color(0xFFD64A3A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: _handleReroute,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Re-route'),
                    ),
                  ],
                ),
              ),
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
                _navIconButton(
                  icon: Icons.explore,
                  onTap: () => _mapController.rotate(0),
                ),
                const SizedBox(height: 6),
                _navIconButton(
                  icon: Icons.my_location,
                  onTap: () => _mapController.move(_currentPosition, 17),
                ),
                const SizedBox(height: 6),
                _navIconButton(
                  icon: Icons.add,
                  onTap: () {
                    final z =
                        (_mapController.camera.zoom + 1).clamp(3.0, 18.0);
                    _mapController.move(_mapController.camera.center, z);
                  },
                ),
                const SizedBox(height: 6),
                _navIconButton(
                  icon: Icons.remove,
                  onTap: () {
                    final z =
                        (_mapController.camera.zoom - 1).clamp(3.0, 18.0);
                    _mapController.move(_mapController.camera.center, z);
                  },
                ),
              ],
            ),
          ),
          if (!_isFullScreen && _nearbyWithin20m.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: _hikeStatus == _HikeStatus.notStarted ? 110 : 220,
              child: SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _nearbyWithin20m.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final p = _nearbyWithin20m[i];
                    return Container(
                      width: 180,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                p.color.withValues(alpha: 0.18),
                            child: Icon(p.icon, color: p.color, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(p.distanceKm * 1000).round()} m',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // Positioned(
          //   right: 16,
          //   bottom: 146,
          //   child: GestureDetector(
          //     onTap: () {
          //       Navigator.push(
          //         context,
          //         MaterialPageRoute(
          //           builder: (_) => const SosScreen(),
          //           fullscreenDialog: true,
          //         ),
          //       );
          //     },
          //     child: Container(
          //       width: 56,
          //       height: 56,
          //       decoration: const BoxDecoration(
          //         color: Color(0xFFD84B3C),
          //         shape: BoxShape.circle,
          //       ),
          //       alignment: Alignment.center,
          //       child: const Text(
          //         'SOS',
          //         style: TextStyle(
          //           color: Colors.white,
          //           fontWeight: FontWeight.w900,
          //           fontSize: 16,
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
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

  Widget _buildBottomStatsPanel(double destinationKm) {
    if (_hikeStatus == _HikeStatus.notStarted) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _startHike,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            icon: const Icon(Icons.play_arrow, size: 28),
            label: const Text(
              'Commencer le Trail',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
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

    final remainStr = destinationKm < 1
        ? '${(destinationKm * 1000).round()} m'
        : '${destinationKm.toStringAsFixed(1)} km';

    final altStr = '${_currentAltitude.round()} m';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
          // Row 1 : temps | distance parcourue | vitesse
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
            ],
          ),
          const SizedBox(height: 6),
          // Row 2 : distance restante | altitude
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricItem(remainStr, 'Restant', Icons.flag_outlined),
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

enum _MapVisualStyle {
  standard('Normal', 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'),
  relief('Relief', 'https://tile.opentopomap.org/{z}/{x}/{y}.png'),
  dark('Dark', 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'),
  satellite('Satellite', 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}');

  final String label;
  final String urlTemplate;

  const _MapVisualStyle(this.label, this.urlTemplate);
}

enum _HikeStatus { notStarted, inProgress, paused, finished }
