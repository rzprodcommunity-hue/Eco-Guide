import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/location_service.dart';
import '../../models/local_service.dart';
import '../../models/poi.dart';
import '../../models/trail.dart';
import '../../providers/local_service_provider.dart';
import '../../providers/locale_provider.dart';
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
  final MapOfflineService _mapOfflineService = MapOfflineService();
  Timer? _gpsTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOnline = true;

  LatLng _currentPosition = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );

  bool _isLoading = false;
  bool _isRouting = false;
  bool _styleAutoSet = false;
  _MapVisualStyle _mapStyle = _MapVisualStyle.standard;

  LatLng? _activeOrigin;
  LatLng? _activeDestination;
  String? _activeOriginLabel;
  String? _activeDestinationLabel;
  final bool _useCurrentPositionAsOrigin = true;
  List<LatLng> _routePoints = [];

  final Set<String> _dismissedNearbyKeys = <String>{};
  final FlutterTts _tts = FlutterTts();
  String? _speakingItemKey;

  bool _showTrails = true;
  bool _showPois = true;
  bool _showServices = true;

  @override
  void initState() {
    super.initState();
    _mapOfflineService.initialize();
    _activeOrigin = _currentPosition;
    _activeOriginLabel = 'Ma position';
    _activeDestination = widget.destination;
    _activeDestinationLabel = widget.destinationLabel;

    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speakingItemKey = null);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speakingItemKey = null);
    });

    Connectivity().checkConnectivity().then((results) {
      if (mounted) {
        setState(() => _isOnline = !results.contains(ConnectivityResult.none));
      }
    });
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() => _isOnline = !results.contains(ConnectivityResult.none));
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMapData();
      _detectUserPosition();
      _startGpsTracking();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_styleAutoSet) {
      _styleAutoSet = true;
      if (Theme.of(context).brightness == Brightness.dark) {
        _mapStyle = _MapVisualStyle.satellite;
      }
    }
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _connectivitySub?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleVoice(_NearbyItem item) async {
    final key = _nearbyItemKey(item);
    if (_speakingItemKey == key) {
      await _tts.stop();
      if (mounted) setState(() => _speakingItemKey = null);
      return;
    }

    final langCode = context.read<LocaleProvider>().locale.languageCode;
    await _tts.stop();
    await _tts.setLanguage(
      langCode == 'ar'
          ? 'ar-SA'
          : langCode == 'en'
              ? 'en-US'
              : 'fr-FR',
    );
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);

    String text = item.name;
    if (item.poi != null) {
      text = '${item.poi!.name}. ${item.poi!.description}';
    } else if (item.trail != null) {
      text =
          '${item.trail!.name}. ${item.trail!.description}. Difficulté ${item.trail!.difficulty}.';
    } else if (item.service != null) {
      text = '${item.service!.name}. ${item.service!.description}';
    }

    if (mounted) setState(() => _speakingItemKey = key);
    await _tts.speak(text);
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

  Future<void> _detectUserPosition({bool feedback = false}) async {
    final result = await LocationService.getBestFix();
    if (!result.isSuccess) {
      debugPrint('[GPS] no fix: ${result.message}');
      return;
    }

    final fix = result.fix!;
    if (!mounted) return;
    setState(() {
      _currentPosition = LatLng(fix.latitude, fix.longitude);
    });

    _mapController.move(
      _activeDestination ?? _currentPosition,
      _mapStyle.maxZoom.clamp(14, 18),
    );
    debugPrint(
      '[GPS] fix lat=${fix.latitude.toStringAsFixed(6)} '
      'lng=${fix.longitude.toStringAsFixed(6)} '
      'accuracy=${fix.accuracy.toStringAsFixed(1)}m',
    );
    if (_activeDestination != null) {
      _refreshRoute(force: true);
    }
  }

  Future<void> _updatePositionSilently() async {
    final fix = await LocationService.getQuickFix();
    if (fix == null || !mounted) return;
    setState(() {
      _currentPosition = LatLng(fix.latitude, fix.longitude);
    });
    _refreshRoute();
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
          .map(
            (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
          )
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
      trails: _showTrails ? trails : const [],
      pois: _showPois ? pois : const [],
      services: _showServices ? services : const [],
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
              minZoom: 3,
              maxZoom: _mapStyle.maxZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: _mapStyle.urlTemplate,
                userAgentPackageName: 'com.ecoguide.app',
                maxZoom: _mapStyle.maxZoom,
                maxNativeZoom: _mapStyle.maxZoom.toInt(),
                tileProvider: LocalFirstTileProvider(
                  service: _mapOfflineService,
                ),
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
                  if (_showTrails) ..._buildTrailMarkers(trails),
                  if (_showPois) ..._buildPoiMarkers(pois),
                  if (_showServices) ..._buildServiceMarkers(services),
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
                        color: Theme.of(context).cardColor,
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
                        icon: Icon(
                          Icons.menu,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: () => _openNearbyListSheet(
                          trails: trails,
                          pois: pois,
                          services: services,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapSearchResultsScreen(
                                currentPosition: _currentPosition,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.54),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Search trails or POIs...',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.54),
                                    fontSize: 14,
                                  ),
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
                        color: Theme.of(context).cardColor,
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
                        icon: Icon(
                          Icons.filter_list,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: _openCategoryFilterSheet,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
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
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
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
            // Lift the controls above the floating bottom navigation badge so
            // the zoom/locate buttons and nearby cards are never hidden.
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildOfflineIndicator(),
                      ),
                      _buildActionColumn(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (notifications.isNotEmpty) _buildNearbyPanel(notifications),
              ],
            ),
          ),

          if (_isLoading ||
              _isRouting ||
              trailProvider.isLoading ||
              poiProvider.isLoading ||
              localServiceProvider.isLoading)
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
        _buildRoundButton(icon: Icons.layers, onPressed: _cycleMapStyle),
        const SizedBox(height: 8),
        _buildRoundButton(
          icon: Icons.explore,
          onPressed: () => _mapController.rotate(0),
        ),
        const SizedBox(height: 8),
        _buildRoundButton(
          icon: Icons.my_location,
          onPressed: () => _detectUserPosition(feedback: true),
        ),
        const SizedBox(height: 8),
        _buildRoundButton(
          icon: Icons.add,
          onPressed: () {
            final next = (_mapController.camera.zoom + 1)
                .clamp(3.0, _mapStyle.maxZoom);
            _mapController.move(_mapController.camera.center, next);
          },
        ),
        const SizedBox(height: 8),
        _buildRoundButton(
          icon: Icons.remove,
          onPressed: () {
            final next = (_mapController.camera.zoom - 1)
                .clamp(3.0, _mapStyle.maxZoom);
            _mapController.move(_mapController.camera.center, next);
          },
        ),
      ],
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
        icon: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }

  // ignore: unused_element
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
    const onlineColor = Color(0xFF0E7A23);
    const offlineColor = Color(0xFFE53935);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = _isOnline ? onlineColor : offlineColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? dotColor.withValues(alpha: 0.1)
            : dotColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dotColor.withValues(alpha: isDark ? 0.3 : 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline ? 'Mode en ligne' : 'Mode hors ligne',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCategoryFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).dividerColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Filtrer les markers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    secondary: const Icon(
                      Icons.terrain,
                      color: Color(0xFF2E7D32),
                    ),
                    title: const Text('Sentiers'),
                    value: _showTrails,
                    onChanged: (v) {
                      setSheetState(() {});
                      setState(() => _showTrails = v);
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.place, color: Colors.black87),
                    title: const Text("Points d'intérêt"),
                    value: _showPois,
                    onChanged: (v) {
                      setSheetState(() {});
                      setState(() => _showPois = v);
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(
                      Icons.storefront,
                      color: Color(0xFF1E9A35),
                    ),
                    title: const Text('Services locaux'),
                    value: _showServices,
                    onChanged: (v) {
                      setSheetState(() {});
                      setState(() => _showServices = v);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNearbyListSheet({
    required List<Trail> trails,
    required List<Poi> pois,
    required List<LocalService> services,
  }) async {
    final items = _collectNearbyItems(
      trails: _showTrails ? trails : const [],
      pois: _showPois ? pois : const [],
      services: _showServices ? services : const [],
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, scrollController) => Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'À proximité (${items.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text('Aucun élément à proximité'),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final item = items[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  item.color.withValues(alpha: 0.18),
                              child: Icon(item.icon, color: item.color),
                            ),
                            title: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${item.subtitle} · ${item.distanceKm.toStringAsFixed(1)} km',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(ctx);
                              _onNearbyTap(item);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
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

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _buildNearbyCard(items[index]),
      ),
    );
  }

  Widget _buildNearbyCard(_NearbyItem item) {
    String? imageUrl;
    if (item.trail != null) {
      if (item.trail!.imageUrls != null && item.trail!.imageUrls!.isNotEmpty) {
        imageUrl = item.trail!.imageUrls!.first;
      }
    } else if (item.poi != null) {
      imageUrl = item.poi!.mediaUrl;
    }

    final isSpeaking = _speakingItemKey == _nearbyItemKey(item);

    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _onNearbyTap(item),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _imageFallback(item),
                          )
                        : _imageFallback(item),
                  ),
                ),
                const SizedBox(height: 4),
                // Row 2: Title
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    height: 1.1,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                // Row 3: Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCardButton(
                      icon: isSpeaking
                          ? Icons.stop_rounded
                          : Icons.volume_up_rounded,
                      color: const Color(0xFF0E7A23),
                      onTap: () => _toggleVoice(item),
                    ),
                    _buildCardButton(
                      icon: Icons.close_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                      onTap: () => _dismissNearbyItem(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _imageFallback(_NearbyItem item) {
    return Container(
      color: item.color.withValues(alpha: 0.15),
      child: Icon(item.icon, color: item.color, size: 28),
    );
  }

  List<_NearbyItem> _getVisibleNearbyNotifications(List<_NearbyItem> items) {
    final visible = <_NearbyItem>[];
    for (final item in items) {
      if (!_dismissedNearbyKeys.contains(_nearbyItemKey(item))) {
        visible.add(item);
      }
    }
    return visible;
  }

  void _dismissNearbyItem(_NearbyItem item) {
    setState(() {
      _dismissedNearbyKeys.add(_nearbyItemKey(item));
    });
  }

  String _nearbyItemKey(_NearbyItem item) {
    return '${item.type.name}:${item.latitude.toStringAsFixed(5)}:${item.longitude.toStringAsFixed(5)}:${item.name}';
  }

  // ignore: unused_element
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
        const SnackBar(
          content: Text('Pas assez de points pour planifier un itineraire.'),
        ),
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
                        .map(
                          (o) => DropdownMenuItem<_RoutePointOption>(
                            value: o,
                            child: Text(
                              o.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
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
                        .map(
                          (o) => DropdownMenuItem<_RoutePointOption>(
                            value: o,
                            child: Text(
                              o.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
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
                _mapController.move(
                  LatLng(trail.startLatitude!, trail.startLongitude!),
                  15,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrailDetailScreen(trail: trail),
                  ),
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
                _mapController.move(
                  LatLng(service.latitude!, service.longitude!),
                  15,
                );
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
          MaterialPageRoute(
            builder: (_) => TrailDetailScreen(trail: item.trail!),
          ),
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
  standard(
    'Normal',
    'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
    19,
  ),
  relief('Relief', 'https://tile.opentopomap.org/{z}/{x}/{y}.png', 17),
  dark(
    'Dark',
    'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
    19,
  ),
  satellite(
    'Satellite',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    18,
  );

  final String label;
  final String urlTemplate;
  final double maxZoom;

  const _MapVisualStyle(this.label, this.urlTemplate, this.maxZoom);
}
