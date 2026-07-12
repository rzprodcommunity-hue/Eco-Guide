import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/track_point.dart';
import '../models/trail.dart';
import '../services/location_service.dart';
import '../services/map_offline_service.dart';
import '../services/storage_service.dart';
import '../utils/formatters.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final LocationService _location = LocationService();
  final StorageService _storage = StorageService();
  final MapController _mapController = MapController();
  final MapOfflineService _mapOffline = MapOfflineService();

  // Initial map focus — the area covered by the offline tile pack.
  static final LatLng _jbelChitanaCenter = LatLng(
    (TileBounds.jbelChitana.minLat + TileBounds.jbelChitana.maxLat) / 2,
    (TileBounds.jbelChitana.minLng + TileBounds.jbelChitana.maxLng) / 2,
  );
  static const double _jbelChitanaZoom = 13;

  final List<TrackPoint> _points = [];
  DateTime? _startedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  bool _paused = false;
  bool _mapReady = false;
  bool _locating = false;
  LatLng? _myLocation;
  String? _error;
  // Set to true on the first GPS fix so we don't keep yanking the camera
  // back to the user once they've started panning manually.
  bool _hasCenteredOnUser = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _location.stop();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _mapOffline.initialize();
    final granted = await _location.ensurePermissions();
    if (!granted) {
      setState(() => _error =
          'Permission GPS refusée ou service localisation désactivé.');
      return;
    }
    // Snappy: snap-to-last-known instantly, then upgrade to a fresh fix.
    _location.bestEffortPosition(onFix: _onLocationFix);
  }

  void _onLocationFix(dynamic pos) {
    if (!mounted) return;
    final here = LatLng(pos.latitude as double, pos.longitude as double);
    setState(() => _myLocation = here);
    if (_hasCenteredOnUser) return;
    _hasCenteredOnUser = true;
    if (_mapReady) {
      _mapController.move(here, 16);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mapReady) _mapController.move(here, 16);
      });
    }
  }

  void _startRecording() {
    if (_recording) return;
    setState(() {
      _points.clear();
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
      _recording = true;
      _paused = false;
      _error = null;
    });

    _location.start(
      onPoint: (p) {
        if (_paused) return;
        setState(() => _points.add(p));
        if (_mapReady) {
          _mapController.move(LatLng(p.latitude, p.longitude),
              _mapController.camera.zoom);
        }
      },
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused || _startedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt!));
    });
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    final granted = await _location.ensurePermissions();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission GPS refusée ou localisation désactivée.'),
        ),
      );
      setState(() => _locating = false);
      return;
    }

    var moved = false;
    await _location.bestEffortPosition(
      onFix: (pos) {
        if (!mounted) return;
        final here = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _myLocation = here;
          _locating = false;
        });
        if (_mapReady) _mapController.move(here, 16);
        moved = true;
      },
    );
    if (!mounted) return;
    if (!moved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Position introuvable.')),
      );
      setState(() => _locating = false);
    }
  }

  Future<void> _stopAndSave() async {
    if (!_recording) return;
    _ticker?.cancel();
    await _location.stop();

    if (_points.length < 2) {
      setState(() {
        _recording = false;
        _paused = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trajet trop court, non enregistré.')),
        );
      }
      return;
    }

    final name = await _askName();
    if (name == null) {
      // User cancelled save — keep recording state cleared but discard.
      setState(() {
        _recording = false;
        _paused = false;
      });
      return;
    }

    final trail = Trail(
      id: 'trail-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      startedAt: _startedAt!,
      endedAt: DateTime.now(),
      points: List.of(_points),
    );
    await _storage.saveTrail(trail);

    if (!mounted) return;
    setState(() {
      _recording = false;
      _paused = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Trajet « $name » enregistré.')),
    );
  }

  Future<String?> _askName() async {
    final controller = TextEditingController(
      text: 'Trajet ${formatDateTime(DateTime.now())}',
    );
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nom du trajet'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Mon trajet du matin'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  double get _distance {
    if (_points.length < 2) return 0;
    return Trail(
      id: '_',
      name: '_',
      startedAt: _startedAt ?? DateTime.now(),
      points: _points,
    ).distanceMeters;
  }

  double get _avgSpeed {
    final secs = _elapsed.inSeconds;
    if (secs == 0) return 0;
    return _distance / secs;
  }

  @override
  Widget build(BuildContext context) {
    final polylinePoints =
        _points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final lastPoint = polylinePoints.isNotEmpty ? polylinePoints.last : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau trajet')),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Text(_error!,
                  style: TextStyle(color: Colors.red.shade900)),
            ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                initialCenter: _jbelChitanaCenter,
                initialZoom: _jbelChitanaZoom,
                onMapReady: () {
                  setState(() => _mapReady = true);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: MapOfflineService.tileUrlTemplate,
                  userAgentPackageName: 'com.example.app_geo',
                  maxZoom: 19,
                  // Offline-first: serves cached tiles, else network.
                  tileProvider: LocalFirstTileProvider(service: _mapOffline),
                ),
                if (polylinePoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: polylinePoints,
                        strokeWidth: 5,
                        color: const Color(0xFF22B53A),
                      ),
                    ],
                  ),
                if (lastPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: lastPoint,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
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
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
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
                    heroTag: 'locate_record',
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
              ],
            ),
          ),
          _StatsBar(
            duration: _elapsed,
            distance: _distance,
            avgSpeed: _avgSpeed,
            pointCount: _points.length,
          ),
          _Controls(
            recording: _recording,
            paused: _paused,
            onStart: _startRecording,
            onPauseResume: _togglePause,
            onStop: _stopAndSave,
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final Duration duration;
  final double distance;
  final double avgSpeed;
  final int pointCount;

  const _StatsBar({
    required this.duration,
    required this.distance,
    required this.avgSpeed,
    required this.pointCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: 'Durée', value: formatDuration(duration)),
          _Stat(label: 'Distance', value: formatDistance(distance)),
          _Stat(label: 'Vitesse moy.', value: formatSpeed(avgSpeed)),
          _Stat(label: 'Points', value: '$pointCount'),
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

class _Controls extends StatelessWidget {
  final bool recording;
  final bool paused;
  final VoidCallback onStart;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;

  const _Controls({
    required this.recording,
    required this.paused,
    required this.onStart,
    required this.onPauseResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (!recording)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: onStart,
                  icon: const Icon(Icons.fiber_manual_record),
                  label: const Text('Démarrer',
                      style: TextStyle(fontSize: 16)),
                ),
              )
            else ...[
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: onPauseResume,
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                  label: Text(paused ? 'Reprendre' : 'Pause'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: onStop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Arrêter'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
