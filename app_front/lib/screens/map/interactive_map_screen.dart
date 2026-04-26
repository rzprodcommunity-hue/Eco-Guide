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
import '../../services/map_offline_service.dart';
import 'map_search_results_screen.dart';
import 'navigation_sos_screen.dart';
import '../poi/poi_detail_screen.dart';
import '../services/local_service_detail_screen.dart';
import '../trails/trail_detail_screen.dart';

class InteractiveMapScreen extends StatefulWidget {
  final LatLng? destination;
  final String? destinationLabel;

  const InteractiveMapScreen({
    super.key,
    this.destination,
    this.destinationLabel,
  });

  @override
  State<InteractiveMapScreen> createState() => _InteractiveMapScreenState();
}

class _InteractiveMapScreenState extends State<InteractiveMapScreen> {
  static const Distance _distance = Distance();

  final MapController _mapController = MapController();
  Timer? _gpsTimer;

  LatLng _currentPosition = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );

  bool _isLoading = false;
  bool _isRouting = false;
  _MapVisualStyle _mapStyle = _MapVisualStyle.standard;

  LatLng? _activeOrigin;
  LatLng? _activeDestination;
  String? _activeOriginLabel;
  String? _activeDestinationLabel;
  bool _useCurrentPositionAsOrigin = true;
  List<LatLng> _routePoints = [];

  final Set<String> _dismissedNearbyKeys = <String>{};
  final Map<String, DateTime> _nearbyFirstSeenAt = <String, DateTime>{};

  @override
  void initState() {
    super.initState();
    _activeOrigin = _currentPosition;
    _activeOriginLabel = 'Ma position';
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

  void _startGpsTracking() {
    _gpsTimer?.cancel();
    _gpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updatePositionSilently();
    });
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
    setState(() => _isLoading = false);
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
      _refreshRoute(force: true);
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
      _refreshRoute();
    } catch (_) {
      // Ignore temporary GPS failures.
    }
  }

  LatLng get _routingOrigin {
    if (_useCurrentPositionAsOrigin) return _currentPosition;
    return _activeOrigin ?? _currentPosition;
  }

  Future<void> _refreshRoute({bool force = false}) async {
    if (_activeDestination == null || !mounted) return;
    if (!force && _isRouting) return;

    final origin = _routingOrigin;
    final destination = _activeDestination!;

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
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
          .where((p) => p.length >= 2)
          .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
          .toList();

      if (!mounted) return;
      setState(() => _routePoints = points);
    } catch (_) {
      // Keep fallback straight line.
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trailProvider = context.watch<TrailProvider>();
    final poiProvider = context.watch<PoiProvider>();
    final localServiceProvider = context.watch<LocalServiceProvider>();

    final trails = trailProvider.trails;
    final pois = poiProvider.pois;
    final services = localServiceProvider.services;

    final nearbyItems = _collectNearbyItems(
      trails: trails,
      pois: pois,
      services: services,
    );
    final notifications = _getVisibleNearbyNotifications(nearbyItems);

    final destination = _activeDestination;
    final hasDestination = destination != null;

    return Scaffold(
      appBar: const EcoPageHeader(title: 'Carte Interactive'),
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
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.ecoguide.app',
                tileProvider: LocalFirstTileProvider(),
              ),
              if (hasDestination)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints.isNotEmpty
                          ? _routePoints
                          : [_routingOrigin, destination],
                      strokeWidth: 4,
                      color: Colors.green,
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
                      child: Icon(Icons.person_pin_circle, color: Colors.white),
                    ),
                  ),
                  if (hasDestination)
                    Marker(
                      point: destination,
                      width: 36,
                      height: 36,
                      child: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.flag, color: Colors.white),
                      ),
                    ),
                  ..._buildTrailMarkers(trails),
                  ..._buildPoiMarkers(pois),
                  ..._buildServiceMarkers(services),
                ],
              ),
            ],
          ),
          if (hasDestination)
            Positioned(
              left: 12,
              right: 12,
              top: 66,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_activeOriginLabel ?? 'Depart'} -> ${_activeDestinationLabel ?? 'Destination'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            right: 12,
            top: 90,
            child: _buildActionColumn(),
          ),
          if (notifications.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 84,
              child: _buildNearbyPanel(notifications),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: FilledButton.icon(
                onPressed: () => _showRoutePlanner(
                  trails: trails,
                  pois: pois,
                  services: services,
                ),
                icon: const Icon(Icons.route),
                label: const Text('Destination'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          if (_isLoading || _isRouting || trailProvider.isLoading || poiProvider.isLoading || localServiceProvider.isLoading)
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

  Widget _buildActionColumn() {
    return Column(
      children: [
        FloatingActionButton.small(
          heroTag: 'mapCenterBtn',
          onPressed: () => _mapController.move(_currentPosition, 14),
          child: const Icon(Icons.my_location),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'mapStyleBtn',
          onPressed: _cycleMapStyle,
          child: const Icon(Icons.layers),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'mapSearchBtn',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MapSearchResultsScreen(
                  currentPosition: _currentPosition,
                ),
              ),
            );
          },
          child: const Icon(Icons.search),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'mapZoomInBtn',
          onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'mapZoomOutBtn',
          onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
          child: const Icon(Icons.remove),
        ),
      ],
    );
  }

  void _cycleMapStyle() {
    final styles = _MapVisualStyle.values;
    final currentIndex = styles.indexOf(_mapStyle);
    final nextIndex = (currentIndex + 1) % styles.length;
    final nextStyle = styles[nextIndex];
    setState(() => _mapStyle = nextStyle);
  }

  Widget _buildNearbyPanel(List<_NearbyItem> items) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: items.take(2).map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: item.color.withValues(alpha: 0.14),
                    child: Icon(item.icon, color: item.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.subtitle} • ${item.distanceKm.toStringAsFixed(1)} km',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: () => _startDirectionsTo(item),
                              icon: const Icon(Icons.route, size: 16),
                              label: const Text('Direction'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _onNearbyTap(item),
                              child: const Text('Voir'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    onPressed: () => _dismissNearbyNotification(item),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<_NearbyItem> _getVisibleNearbyNotifications(List<_NearbyItem> items) {
    final now = DateTime.now();
    const maxDuration = Duration(seconds: 12);

    final currentKeys = items.map(_nearbyItemKey).toSet();
    _nearbyFirstSeenAt.removeWhere((key, _) => !currentKeys.contains(key));

    final visible = <_NearbyItem>[];
    for (final item in items) {
      final key = _nearbyItemKey(item);
      if (_dismissedNearbyKeys.contains(key)) continue;
      _nearbyFirstSeenAt.putIfAbsent(key, () => now);
      if (now.difference(_nearbyFirstSeenAt[key]!) <= maxDuration) {
        visible.add(item);
      }
    }

    return visible;
  }

  String _nearbyItemKey(_NearbyItem item) {
    return '${item.type.name}:${item.latitude.toStringAsFixed(5)}:${item.longitude.toStringAsFixed(5)}:${item.name}';
  }

  void _dismissNearbyNotification(_NearbyItem item) {
    setState(() => _dismissedNearbyKeys.add(_nearbyItemKey(item)));
  }

  void _startDirectionsTo(_NearbyItem item) {
    setState(() {
      _useCurrentPositionAsOrigin = true;
      _activeOrigin = _currentPosition;
      _activeOriginLabel = 'Ma position';
      _activeDestination = LatLng(item.latitude, item.longitude);
      _activeDestinationLabel = item.name;
      _routePoints = [];
    });
    _mapController.move(_activeDestination!, 14);
    _refreshRoute(force: true);
  }

  Future<void> _showRoutePlanner({
    required List<Trail> trails,
    required List<Poi> pois,
    required List<LocalService> services,
  }) async {
    final options = _buildRoutePointOptions(
      trails: trails,
      pois: pois,
      services: services,
    );

    if (options.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pas assez de points pour planifier un itineraire.')),
      );
      return;
    }

    _RoutePointOption origin = options.first;
    _RoutePointOption destination = options[1];

    final planned = await showModalBottomSheet<_PlannedRoute>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) => Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F3ED),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC6B9A6),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Planifier un itineraire',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choisissez depart et destination',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6F6A63)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<_RoutePointOption>(
                    value: origin,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Point de depart',
                      prefixIcon: const Icon(Icons.trip_origin),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE3D7C6)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE3D7C6)),
                      ),
                    ),
                    items: options
                        .map((o) => DropdownMenuItem<_RoutePointOption>(
                              value: o,
                              child: Text(o.label, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => origin = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setSheetState(() {
                            final temp = origin;
                            origin = destination;
                            destination = temp;
                          });
                        },
                        icon: const Icon(Icons.swap_vert),
                        label: const Text('Inverser'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<_RoutePointOption>(
                    value: destination,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Destination',
                      prefixIcon: const Icon(Icons.flag_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE3D7C6)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE3D7C6)),
                      ),
                    ),
                    items: options
                        .map((o) => DropdownMenuItem<_RoutePointOption>(
                              value: o,
                              child: Text(o.label, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => destination = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        _PlannedRoute(origin: origin, destination: destination),
                      ),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Demarrer la navigation'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (planned == null) return;
    if (planned.origin.key == planned.destination.key) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez deux points differents.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NavigationSosScreen(
          destination: planned.destination.point,
          destinationLabel: planned.destination.label,
        ),
      ),
    );
  }

  List<_RoutePointOption> _buildRoutePointOptions({
    required List<Trail> trails,
    required List<Poi> pois,
    required List<LocalService> services,
  }) {
    final options = <_RoutePointOption>[
      _RoutePointOption(
        key: 'current_position',
        label: 'Ma position actuelle',
        point: _currentPosition,
        isCurrentPosition: true,
      ),
    ];

    for (final trail in trails) {
      if (trail.startLatitude == null || trail.startLongitude == null) continue;
      options.add(
        _RoutePointOption(
          key: 'trail_${trail.id}',
          label: 'Trail: ${trail.name}',
          point: LatLng(trail.startLatitude!, trail.startLongitude!),
        ),
      );
    }

    for (final poi in pois) {
      options.add(
        _RoutePointOption(
          key: 'poi_${poi.id}',
          label: 'POI: ${poi.name}',
          point: LatLng(poi.latitude, poi.longitude),
        ),
      );
    }

    for (final service in services) {
      if (service.latitude == null || service.longitude == null) continue;
      options.add(
        _RoutePointOption(
          key: 'service_${service.id}',
          label: 'Service: ${service.name}',
          point: LatLng(service.latitude!, service.longitude!),
        ),
      );
    }

    return options;
  }

  List<Marker> _buildTrailMarkers(List<Trail> trails) {
    return trails
        .where((t) => t.startLatitude != null && t.startLongitude != null)
        .map(
          (trail) => Marker(
            point: LatLng(trail.startLatitude!, trail.startLongitude!),
            width: 38,
            height: 38,
            child: GestureDetector(
              onTap: () {
                _mapController.move(LatLng(trail.startLatitude!, trail.startLongitude!), 15);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TrailDetailScreen(trail: trail)),
                );
              },
              child: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.terrain, color: Colors.white),
              ),
            ),
          ),
        )
        .toList();
  }

  List<Marker> _buildPoiMarkers(List<Poi> pois) {
    return pois
        .map(
          (poi) => Marker(
            point: LatLng(poi.latitude, poi.longitude),
            width: 30,
            height: 30,
            child: GestureDetector(
              onTap: () {
                _mapController.move(LatLng(poi.latitude, poi.longitude), 15);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PoiDetailScreen(poi: poi)),
                );
              },
              child: const CircleAvatar(
                backgroundColor: Color(0xFF212121),
                child: Icon(Icons.place, size: 16, color: Colors.white),
              ),
            ),
          ),
        )
        .toList();
  }

  List<Marker> _buildServiceMarkers(List<LocalService> services) {
    return services
        .where((s) => s.latitude != null && s.longitude != null)
        .map(
          (service) => Marker(
            point: LatLng(service.latitude!, service.longitude!),
            width: 30,
            height: 30,
            child: GestureDetector(
              onTap: () {
                _mapController.move(LatLng(service.latitude!, service.longitude!), 15);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocalServiceDetailScreen(
                      serviceId: service.id,
                      fallbackService: service,
                    ),
                  ),
                );
              },
              child: const CircleAvatar(
                backgroundColor: Color(0xFF1E9A35),
                child: Icon(Icons.storefront, size: 16, color: Colors.white),
              ),
            ),
          ),
        )
        .toList();
  }

  List<_NearbyItem> _collectNearbyItems({
    required List<Trail> trails,
    required List<Poi> pois,
    required List<LocalService> services,
  }) {
    final items = <_NearbyItem>[];

    for (final trail in trails) {
      if (trail.startLatitude == null || trail.startLongitude == null) continue;
      final distanceKm = _distance.as(
        LengthUnit.Kilometer,
        _currentPosition,
        LatLng(trail.startLatitude!, trail.startLongitude!),
      );
      if (distanceKm > 10) continue;
      items.add(
        _NearbyItem(
          type: _NearbyType.trail,
          name: trail.name,
          subtitle: 'Trail',
          icon: Icons.hiking,
          color: Colors.green,
          distanceKm: distanceKm,
          latitude: trail.startLatitude!,
          longitude: trail.startLongitude!,
          trail: trail,
        ),
      );
    }

    for (final poi in pois) {
      final distanceKm = _distance.as(
        LengthUnit.Kilometer,
        _currentPosition,
        LatLng(poi.latitude, poi.longitude),
      );
      if (distanceKm > 10) continue;
      items.add(
        _NearbyItem(
          type: _NearbyType.poi,
          name: poi.name,
          subtitle: 'POI',
          icon: Icons.place,
          color: Colors.black87,
          distanceKm: distanceKm,
          latitude: poi.latitude,
          longitude: poi.longitude,
          poi: poi,
        ),
      );
    }

    for (final service in services) {
      if (service.latitude == null || service.longitude == null) continue;
      final distanceKm = _distance.as(
        LengthUnit.Kilometer,
        _currentPosition,
        LatLng(service.latitude!, service.longitude!),
      );
      if (distanceKm > 10) continue;
      items.add(
        _NearbyItem(
          type: _NearbyType.service,
          name: service.name,
          subtitle: 'Service',
          icon: Icons.storefront,
          color: const Color(0xFF1E9A35),
          distanceKm: distanceKm,
          latitude: service.latitude!,
          longitude: service.longitude!,
          service: service,
        ),
      );
    }

    items.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return items;
  }

  void _onNearbyTap(_NearbyItem item) {
    _mapController.move(LatLng(item.latitude, item.longitude), 15);

    switch (item.type) {
      case _NearbyType.trail:
        if (item.trail == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TrailDetailScreen(trail: item.trail!)),
        );
        return;
      case _NearbyType.poi:
        if (item.poi == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PoiDetailScreen(poi: item.poi!)),
        );
        return;
      case _NearbyType.service:
        if (item.service == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LocalServiceDetailScreen(
              serviceId: item.service!.id,
              fallbackService: item.service!,
            ),
          ),
        );
        return;
    }
  }
}

enum _NearbyType { trail, poi, service }

class _NearbyItem {
  final _NearbyType type;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double distanceKm;
  final double latitude;
  final double longitude;
  final Trail? trail;
  final Poi? poi;
  final LocalService? service;

  _NearbyItem({
    required this.type,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.distanceKm,
    required this.latitude,
    required this.longitude,
    this.trail,
    this.poi,
    this.service,
  });
}

class _PlannedRoute {
  final _RoutePointOption origin;
  final _RoutePointOption destination;

  _PlannedRoute({required this.origin, required this.destination});
}

class _RoutePointOption {
  final String key;
  final String label;
  final LatLng point;
  final bool isCurrentPosition;

  _RoutePointOption({
    required this.key,
    required this.label,
    required this.point,
    this.isCurrentPosition = false,
  });
}

enum _MapVisualStyle {
  standard('Normal', 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'),
  relief('Relief', 'https://tile.opentopomap.org/{z}/{x}/{y}.png'),
  dark('Dark', 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'),
  satellite('Satellite', 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}');

  final String label;
  final String urlTemplate;

  const _MapVisualStyle(this.label, this.urlTemplate);
}
