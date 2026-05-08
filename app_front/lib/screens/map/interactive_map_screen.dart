import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
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
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F3ED),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.menu, color: Colors.black87),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapSearchResultsScreen(currentPosition: _currentPosition),
                            ),
                          );
                        },
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F3ED),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.search, color: Colors.black54),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Search trails or POIs...',
                                  style: TextStyle(color: Colors.black54, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F3ED),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.filter_list, color: Colors.black87),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          if (hasDestination)
            Positioned(
              left: 12,
              right: 12,
              top: 120,
              child: SafeArea(
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
            ),
            
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSOSButton(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildOfflineIndicator(),
                      ),
                      _buildActionColumn(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (notifications.isNotEmpty)
                  _buildNearbyPanel(notifications),
                if (notifications.isNotEmpty)
                  const SizedBox(height: 16),
                _buildBottomNavigationBlock(context),
              ],
            ),
          ),
          
          if (_isLoading || _isRouting || trailProvider.isLoading || poiProvider.isLoading || localServiceProvider.isLoading)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildActionColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRoundButton(
          icon: Icons.layers,
          onPressed: _cycleMapStyle,
        ),
        const SizedBox(height: 8),
        _buildRoundButton(
          icon: Icons.explore,
          onPressed: () {},
        ),
        const SizedBox(height: 8),
        _buildRoundButton(
          icon: Icons.my_location,
          onPressed: () => _mapController.move(_currentPosition, 14),
        ),
        const SizedBox(height: 8),
        _buildRoundButton(
          icon: Icons.add,
          onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
        ),
        const SizedBox(height: 8),
        _buildRoundButton(
          icon: Icons.remove,
          onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
        ),
      ],
    );
  }

  Widget _buildRoundButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3ED),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildSOSButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // SOS action
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade300, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Offline Mode Active',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBlock(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF6F3ED),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Current Position',
                  style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 18, color: Colors.black87),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _activeOriginLabel ?? 'Massif du Mont-Blanc',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: () {
              final trails = context.read<TrailProvider>().trails;
              final pois = context.read<PoiProvider>().pois;
              final services = context.read<LocalServiceProvider>().services;
              _showRoutePlanner(trails: trails, pois: pois, services: services);
            },
            icon: const Icon(Icons.directions_walk),
            label: const Text('Start Navigation'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
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
    if (items.isEmpty) return const SizedBox.shrink();
    final item = items.first;
    
    String difficulty = 'Moderate';
    int durationMins = 135;
    List<String> images = [
      'https://images.unsplash.com/photo-1551632811-561f3222ef86?q=80&w=400&auto=format&fit=crop'
    ];
    
    if (item.trail != null) {
      difficulty = item.trail!.difficulty;
      durationMins = item.trail!.estimatedDuration ?? 135;
      if (item.trail!.imageUrls != null && item.trail!.imageUrls!.isNotEmpty) {
        images = item.trail!.imageUrls!;
      }
    }

    final int h = durationMins ~/ 60;
    final int m = durationMins % 60;
    final durationStr = h > 0 ? '${h}h ${m}m' : '${m}m';

    return GestureDetector(
      onTap: () => _onNearbyTap(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F3ED),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                images.first,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80, height: 80, color: Colors.grey.shade300,
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.terrain, size: 14, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        difficulty,
                        style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        durationStr,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.straighten, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '${item.distanceKm.toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (images.length > 1) ...[
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  images[1],
                  width: 60,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ] else ...[
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=200&auto=format&fit=crop',
                  width: 60,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_NearbyItem> _getVisibleNearbyNotifications(List<_NearbyItem> items) {
    final visible = <_NearbyItem>[];
    for (final item in items) {
      if (!_dismissedNearbyKeys.contains(_nearbyItemKey(item))) {
        visible.add(item);
        break; // Show at most 1 item for the new card design
      }
    }
    return visible;
  }

  String _nearbyItemKey(_NearbyItem item) {
    return '${item.type.name}:${item.latitude.toStringAsFixed(5)}:${item.longitude.toStringAsFixed(5)}:${item.name}';
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
                    initialValue: origin,
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
                    initialValue: destination,
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

    if (!mounted) return;
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
