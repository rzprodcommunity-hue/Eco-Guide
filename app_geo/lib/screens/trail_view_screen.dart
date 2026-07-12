import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../models/trail.dart';
import '../services/location_service.dart';
import '../services/map_offline_service.dart';
import '../services/storage_service.dart';
import '../utils/formatters.dart';
import 'trail_qr_screen.dart';

class TrailViewScreen extends StatefulWidget {
  final Trail trail;
  const TrailViewScreen({super.key, required this.trail});

  @override
  State<TrailViewScreen> createState() => _TrailViewScreenState();
}

class _TrailViewScreenState extends State<TrailViewScreen> {
  final MapOfflineService _mapOffline = MapOfflineService();
  final MapController _mapController = MapController();
  final LocationService _location = LocationService();

  /// Zoom levels pre-cached so the whole trail is browsable offline.
  static const List<int> _offlineZooms = [12, 13, 14, 15, 16];

  bool _downloadingTiles = false;
  double _tileProgress = 0;
  LatLng? _myLocation;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCacheTiles());
  }

  /// Automatically downloads the map tiles covering this trail so it can be
  /// viewed offline later — same idea as the offline map in app_front, but
  /// triggered automatically when a trail is opened (no button).
  Future<void> _autoCacheTiles() async {
    final pts = widget.trail.points;
    // Need at least one valid point — and we guard against NaN/Infinity
    // coordinates that would crash the tile math below.
    if (pts.isEmpty) return;
    bool valid(double v) => v.isFinite;
    final usable = pts
        .where((p) => valid(p.latitude) && valid(p.longitude))
        .toList();
    if (usable.isEmpty) return;

    await _mapOffline.initialize();

    double minLat = usable.first.latitude, maxLat = usable.first.latitude;
    double minLon = usable.first.longitude, maxLon = usable.first.longitude;
    for (final p in usable) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    // Small margin around the track. With a single point the box collapses
    // to a square of side 2 × margin, which is plenty for downloading.
    const margin = 0.01;
    final bounds = TileBounds(
      minLat: minLat - margin,
      maxLat: maxLat + margin,
      minLng: minLon - margin,
      maxLng: maxLon + margin,
    );

    if (!mounted) return;
    setState(() {
      _downloadingTiles = true;
      _tileProgress = 0;
    });

    try {
      await _mapOffline.downloadTiles(
        bounds: bounds,
        zooms: _offlineZooms,
        onProgress: (progress, _, _) {
          if (!mounted) return;
          setState(() => _tileProgress = progress);
        },
      );
    } catch (_) {
      // Offline caching is best-effort; ignore network failures.
    } finally {
      if (mounted) setState(() => _downloadingTiles = false);
    }
  }

  Future<void> _share() async {
    final storage = StorageService();
    try {
      final file = await storage.exportToGpxTempFile(widget.trail);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/gpx+xml')],
        subject: widget.trail.name,
        text: 'Trajet GPX : ${widget.trail.name}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur partage GPX : $e')),
      );
    }
  }

  void _showQr() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrailQrScreen(trail: widget.trail)),
    );
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final granted = await _location.ensurePermissions();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission GPS refusée ou localisation désactivée.'),
          ),
        );
        return;
      }
      final pos = await _location.currentPosition();
      if (pos == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Position introuvable.')),
        );
        return;
      }
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _myLocation = here);
      _mapController.move(here, 16);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Bounding box covering all points. Returns null when there's nothing to
  /// fit OR when every point is at the same coordinates — a degenerate
  /// (zero-width) box would make `CameraFit.bounds` compute an infinite zoom
  /// and crash with "Infinity or NaN toInt".
  LatLngBounds? _bounds(List<LatLng> pts) {
    if (pts.length < 2) return null;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLon = pts.first.longitude, maxLon = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    // All points stacked on the same spot → no real extent. Fall back to
    // initialZoom (caller treats null as "no fit").
    if (maxLat - minLat < 1e-9 && maxLon - minLon < 1e-9) return null;
    return LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
  }

  @override
  Widget build(BuildContext context) {
    final trail = widget.trail;
    final pts = trail.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    final bounds = _bounds(pts);
    final center = pts.isNotEmpty ? pts.first : const LatLng(48.8566, 2.3522);

    return Scaffold(
      appBar: AppBar(
        title: Text(trail.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'QR du sentier',
            icon: const Icon(Icons.qr_code_2),
            onPressed: _showQr,
          ),
          IconButton(
            tooltip: 'Partager en GPX',
            icon: const Icon(Icons.ios_share),
            onPressed: _share,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_downloadingTiles)
            LinearProgressIndicator(
              value: _tileProgress == 0 ? null : _tileProgress,
              minHeight: 3,
              backgroundColor: const Color(0xFF22B53A).withValues(alpha: 0.12),
            ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 14,
                    initialCameraFit: bounds == null
                        ? null
                        : CameraFit.bounds(
                            bounds: bounds,
                            padding: const EdgeInsets.all(40),
                          ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: MapOfflineService.tileUrlTemplate,
                      userAgentPackageName: 'com.example.app_geo',
                      maxZoom: 19,
                      // Offline-first: serves cached tiles, else network.
                      tileProvider: LocalFirstTileProvider(service: _mapOffline),
                    ),
                    if (pts.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: pts,
                            strokeWidth: 5,
                            color: const Color(0xFF22B53A),
                          ),
                        ],
                      ),
                    if (pts.isNotEmpty)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pts.first,
                            width: 28,
                            height: 28,
                            child: _Pin(color: Colors.green),
                          ),
                          Marker(
                            point: pts.last,
                            width: 28,
                            height: 28,
                            child: _Pin(color: Colors.red),
                          ),
                        ],
                      ),
                    if (_myLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _myLocation!,
                            width: 26,
                            height: 26,
                            child: const _MyLocationDot(),
                          ),
                        ],
                      ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton(
                    heroTag: 'locate_trail_view',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF22B53A),
                    onPressed: _locating ? null : _locateMe,
                    child: _locating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
                if (_downloadingTiles)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.download_for_offline,
                              size: 14, color: const Color(0xFF22B53A)),
                          SizedBox(width: 6),
                          Text(
                            'Carte hors ligne…',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF22B53A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDateTime(trail.startedAt),
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(
                      label: 'Distance',
                      value: formatDistance(trail.distanceMeters),
                    ),
                    _Stat(
                      label: 'Durée',
                      value: formatDuration(trail.duration),
                    ),
                    _Stat(
                      label: 'V. moy.',
                      value: formatSpeed(trail.averageSpeed),
                    ),
                    _Stat(
                      label: 'V. max',
                      value: formatSpeed(trail.maxSpeed),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final Color color;
  const _Pin({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
