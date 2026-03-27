import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/eco_page_header.dart';
import '../../models/local_service.dart';
import '../../models/poi.dart';
import '../../models/trail.dart';
import '../../providers/local_service_provider.dart';
import '../../providers/poi_provider.dart';
import '../../providers/trail_provider.dart';
import '../sos/sos_button.dart';

class NavigationSosScreen extends StatefulWidget {
  final LatLng? destination;
  final String? destinationLabel;

  const NavigationSosScreen({
    super.key,
    this.destination,
    this.destinationLabel,
  });

  @override
  State<NavigationSosScreen> createState() => _NavigationSosScreenState();
}

class _NavigationSosScreenState extends State<NavigationSosScreen> {
  static const Distance _distance = Distance();

  final MapController _mapController = MapController();
  Timer? _gpsTimer;

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

  _MapVisualStyle _mapStyle = _MapVisualStyle.standard;

  List<_NavPoint> _nearbyPoints = [];
  _NavPoint? _featuredPoint;

  @override
  void initState() {
    super.initState();
    _activeDestination = widget.destination;
    _activeDestinationLabel = widget.destinationLabel;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMapData();
      _detectUserPosition();
      _startGpsTracking();
    });
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
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
    _gpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updatePositionSilently();
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
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
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
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${_currentPosition.longitude},${_currentPosition.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson',
    );

    setState(() => _isRouting = true);
    try {
      final response = await http.get(url);
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

      if (!mounted) return;
      setState(() {
        _routePoints = points;
      });
    } catch (_) {
      // Fallback is handled by direct line when route data is missing.
    } finally {
      if (mounted) {
        setState(() => _isRouting = false);
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
    if (_routePoints.length < 2) {
      setState(() => _offTrailAlert = false);
      return;
    }

    var minMeters = double.infinity;
    for (final point in _routePoints) {
      final d = _distance.as(LengthUnit.Meter, _currentPosition, point);
      if (d < minMeters) minMeters = d;
    }

    if (!mounted) return;
    setState(() {
      _offTrailAlert = minMeters > 25;
    });
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

  @override
  Widget build(BuildContext context) {
    final destination = _activeDestination;
    final hasDestination = destination != null;
    final destinationKm = hasDestination
        ? _distance.as(LengthUnit.Kilometer, _currentPosition, destination)
        : 0.0;

    return Scaffold(
      appBar: const EcoPageHeader(title: 'Navigation & SOS'),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: destination ?? _currentPosition,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: _mapStyle.urlTemplate,
                userAgentPackageName: 'com.ecoguide.app',
              ),
              if (hasDestination)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints.isNotEmpty
                          ? _routePoints
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
                    width: 34,
                    height: 34,
                    child: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.navigation, color: Colors.white, size: 18),
                    ),
                  ),
                  if (hasDestination)
                    Marker(
                      point: destination,
                      width: 36,
                      height: 36,
                      child: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.flag, color: Colors.white, size: 18),
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
                          child: Icon(point.icon, color: Colors.white, size: 14),
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
              top: 14,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E9A35),
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
                    const Icon(Icons.turn_right, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destinationKm < 1
                                ? '${(destinationKm * 1000).round()}m'
                                : '${destinationKm.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Turn right toward ${_activeDestinationLabel ?? 'destination'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.volume_up, color: Colors.white),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF3F3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE97C74)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65245)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Off-Trail Alert',
                            style: TextStyle(
                              color: Color(0xFFD64A3A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'You are away from the path.',
                            style: TextStyle(fontSize: 12, color: Color(0xFFD64A3A)),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () => _refreshRoute(force: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E9A35),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Re-route'),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            right: 16,
            top: 230,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'navStyleBtn',
                  onPressed: _cycleMapStyle,
                  child: const Icon(Icons.layers),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'navCurrentBtn',
                  onPressed: () => _mapController.move(_currentPosition, 14),
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          if (_featuredPoint != null)
            Positioned(
              left: 16,
              right: 76,
              bottom: 136,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE6DB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD9CCBB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _featuredPoint!.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _featuredPoint!.subtitle,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF5F5F5F)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _selectDestination(_featuredPoint!),
                      icon: const Icon(Icons.gps_fixed, color: Color(0xFF1E9A35)),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 146,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SosScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFD84B3C),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
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
    final remaining = destinationKm <= 0 ? '--' : destinationKm.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFDDD7CE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFC5B49A),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricItem('1h 15m', 'Remaining'),
              _metricItem('$remaining km', 'Distance'),
              _metricItem('4.2 km/h', 'Pace'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6E431F),
                  ),
                  icon: const Icon(Icons.pause, size: 16),
                  label: const Text('Pause Hike'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E9A35),
                  ),
                  icon: const Icon(Icons.flag, size: 16),
                  label: const Text('Finish'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF585858)),
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

enum _MapVisualStyle {
  standard('Normal', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
  relief('Relief', 'https://tile.opentopomap.org/{z}/{x}/{y}.png'),
  dark('Dark', 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'),
  satellite('Satellite', 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}');

  final String label;
  final String urlTemplate;

  const _MapVisualStyle(this.label, this.urlTemplate);
}
