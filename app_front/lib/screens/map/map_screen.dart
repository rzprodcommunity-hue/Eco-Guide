import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/eco_page_header.dart';
import '../../core/widgets/eco_shortcut_badge.dart';
import '../../core/widgets/error_banner.dart';
import '../../providers/trail_provider.dart';
import '../../providers/poi_provider.dart';
import '../../models/trail.dart';
import '../../models/poi.dart';
import '../../services/map_offline_service.dart';
import '../home/home_screen.dart';
import '../trails/trail_detail_screen.dart';
import '../poi/poi_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final MapOfflineService _mapOfflineService = MapOfflineService();
  LatLng _currentPosition = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  String? _locationError;
  bool _hasOfflineMap = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _initializeOfflineMap();
      _detectUserPosition(centerMap: false);
    });
  }

  Future<void> _initializeOfflineMap() async {
    await _mapOfflineService.initialize();
    final hasOffline = await _mapOfflineService.hasAnyOfflineTile();
    if (!mounted) return;
    setState(() {
      _hasOfflineMap = hasOffline;
    });
  }

  void _loadData() {
    context.read<TrailProvider>().loadTrails(refresh: true);
    context.read<PoiProvider>().loadPois();
  }

  Future<void> _detectUserPosition({bool centerMap = true}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationError =
              'Le service de localisation est desactive. Activez le GPS.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationError =
              'Permission de localisation refusee. Autorisez-la dans les parametres.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      final userPosition = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = userPosition;
        _locationError = null;
      });

      if (centerMap) {
        _mapController.move(userPosition, 14);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError =
            'Impossible de recuperer votre position GPS pour le moment.';
      });
    }
  }

  void _centerOnUser() {
    _detectUserPosition(centerMap: true);
  }

  List<Marker> _buildPoiMarkers(List<Poi> pois) {
    return pois.map((poi) {
      return Marker(
        point: LatLng(poi.latitude, poi.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showPoiDetail(poi),
          child: Container(
            decoration: BoxDecoration(
              color: _getPoiColor(poi.type),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(_getPoiIcon(poi.type), color: Colors.white, size: 20),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildTrailStartMarkers(List<Trail> trails) {
    return trails
        .where((t) => t.startLatitude != null && t.startLongitude != null)
        .map((trail) {
          return Marker(
            point: LatLng(trail.startLatitude!, trail.startLongitude!),
            width: 50,
            height: 50,
            child: GestureDetector(
              onTap: () => _showTrailDetail(trail),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.hiking, color: Colors.white, size: 24),
              ),
            ),
          );
        })
        .toList();
  }

  Color _getPoiColor(String type) {
    switch (type) {
      case 'viewpoint':
        return Colors.blue;
      case 'flora':
        return Colors.green;
      case 'fauna':
        return Colors.orange;
      case 'historical':
        return Colors.brown;
      case 'water':
        return Colors.cyan;
      case 'camping':
        return Colors.teal;
      case 'danger':
        return Colors.red;
      case 'rest_area':
        return Colors.purple;
      case 'information':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getPoiIcon(String type) {
    switch (type) {
      case 'viewpoint':
        return Icons.photo_camera;
      case 'flora':
        return Icons.local_florist;
      case 'fauna':
        return Icons.pets;
      case 'historical':
        return Icons.museum;
      case 'water':
        return Icons.water_drop;
      case 'camping':
        return Icons.cabin;
      case 'danger':
        return Icons.warning;
      case 'rest_area':
        return Icons.chair;
      case 'information':
        return Icons.info;
      default:
        return Icons.place;
    }
  }

  void _showTrailDetail(Trail trail) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrailDetailScreen(trail: trail)),
    );
  }

  void _showPoiDetail(Poi poi) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PoiDetailScreen(poi: poi)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trailProvider = context.watch<TrailProvider>();
    final poiProvider = context.watch<PoiProvider>();

    return Scaffold(
      appBar: EcoPageHeader(
        title: 'Eco-Guide',
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      bottomNavigationBar: EcoShortcutBadge(
        currentTab: EcoShortcutTab.map,
        onTabSelected: (tab) {
          final index = switch (tab) {
            EcoShortcutTab.home => 0,
            EcoShortcutTab.map => 1,
            EcoShortcutTab.trails => 2,
            EcoShortcutTab.quiz => 4,
            EcoShortcutTab.services => 6,
            EcoShortcutTab.settings => 7,
          };
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomeScreen(initialIndex: index)),
            (route) => false,
          );
        },
      ),
      body: Column(
        children: [
          if (trailProvider.error != null && trailProvider.error!.isNotEmpty)
            ErrorBanner(
              message: trailProvider.error!,
              onRetry: _loadData,
              onDismiss: trailProvider.clearError,
            ),
          if (poiProvider.error != null && poiProvider.error!.isNotEmpty)
            ErrorBanner(
              message: poiProvider.error!,
              onRetry: _loadData,
              onDismiss: poiProvider.clearError,
            ),
          if (_locationError != null)
            ErrorBanner(
              message: _locationError!,
              onRetry: () => _detectUserPosition(centerMap: true),
              onDismiss: () => setState(() => _locationError = null),
            ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition,
                    initialZoom: AppConstants.defaultZoom,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.ecoguide.app',
                      tileProvider: LocalFirstTileProvider(service: _mapOfflineService),
                    ),
                    MarkerLayer(
                      markers: [
                        // Current position marker
                        Marker(
                          point: _currentPosition,
                          width: 30,
                          height: 30,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                        // Trail markers
                        ..._buildTrailStartMarkers(trailProvider.trails),
                        // POI markers
                        ..._buildPoiMarkers(poiProvider.pois),
                      ],
                    ),
                  ],
                ),
                // Loading indicator
                if (trailProvider.isLoading || poiProvider.isLoading)
                  const Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Center on user button
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'centerMap',
                    onPressed: _centerOnUser,
                    child: const Icon(Icons.my_location),
                  ),
                ),
                if (_hasOfflineMap)
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Carte Tabarka offline activee',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


