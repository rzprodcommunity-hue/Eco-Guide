import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../providers/trail_provider.dart';

class RecordTrailScreen extends StatefulWidget {
  const RecordTrailScreen({super.key});

  @override
  State<RecordTrailScreen> createState() => _RecordTrailScreenState();
}

class _RecordTrailScreenState extends State<RecordTrailScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _points = [];

  bool _recording = false;
  bool _paused = false;
  DateTime? _startedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  StreamSubscription<Position>? _positionStream;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final ok = await _ensurePermission();
    if (!ok) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      if (mounted) _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
    } catch (_) {}
  }

  Future<bool> _ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => _error = 'Service de localisation desactive.');
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      setState(() => _error = 'Permission de localisation refusee.');
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  void _start() {
    if (_recording) return;
    setState(() {
      _points.clear();
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
      _recording = true;
      _paused = false;
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((pos) {
      if (!mounted || _paused) return;
      final p = LatLng(pos.latitude, pos.longitude);
      if (_points.isNotEmpty) {
        const d = Distance();
        final m = d.as(LengthUnit.Meter, _points.last, p);
        if (m < 1.5) return;
      }
      setState(() => _points.add(p));
      _mapController.move(p, _mapController.camera.zoom);
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused || _startedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt!));
    });
  }

  void _togglePause() => setState(() => _paused = !_paused);

  Future<void> _stop() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _ticker?.cancel();

    if (_points.length < 2) {
      setState(() {
        _recording = false;
        _paused = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trajet trop court, non enregistre.')),
        );
      }
      return;
    }

    final details = await _askDetails();
    if (details == null || !mounted) {
      setState(() {
        _recording = false;
        _paused = false;
      });
      return;
    }

    final coordinates = _points
        .map((p) => [p.longitude, p.latitude])
        .toList();
    final distanceKm = _computeDistanceMeters() / 1000.0;

    final payload = <String, dynamic>{
      'name': details['name'],
      'description': details['description'] ?? '',
      'difficulty': details['difficulty'] ?? 'moderate',
      'distance': double.parse(distanceKm.toStringAsFixed(3)),
      'estimatedDuration': _elapsed.inMinutes,
      'startLatitude': _points.first.latitude,
      'startLongitude': _points.first.longitude,
      'geojson': {
        'type': 'LineString',
        'coordinates': coordinates,
      },
      'isActive': true,
    };

    final provider = context.read<TrailProvider>();
    final created = await provider.createTrail(payload);

    if (!mounted) return;
    setState(() {
      _recording = false;
      _paused = false;
    });

    if (created != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sentier « ${created.name} » enregistre.')),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${provider.error ?? 'inconnue'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _askDetails() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String difficulty = 'moderate';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Enregistrer le sentier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nom du sentier *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: difficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulte',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'easy', child: Text('Facile')),
                    DropdownMenuItem(value: 'moderate', child: Text('Modere')),
                    DropdownMenuItem(value: 'difficult', child: Text('Difficile')),
                  ],
                  onChanged: (v) =>
                      setLocal(() => difficulty = v ?? 'moderate'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop({
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'difficulty': difficulty,
                });
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  double _computeDistanceMeters() {
    if (_points.length < 2) return 0;
    const d = Distance();
    double total = 0;
    for (var i = 1; i < _points.length; i++) {
      total += d.as(LengthUnit.Meter, _points[i - 1], _points[i]);
    }
    return total;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    final distance = _computeDistanceMeters();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enregistrer un sentier'),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(36.8065, 10.1815),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ecoguide.app',
                  maxZoom: 19,
                ),
                if (_points.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _points,
                        strokeWidth: 5,
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),
                if (_points.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _points.first,
                        width: 24,
                        height: 24,
                        child: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
                      Marker(
                        point: _points.last,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
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
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(label: 'Duree', value: _formatDuration(_elapsed)),
                _Stat(label: 'Distance', value: _formatDistance(distance)),
                _Stat(label: 'Points', value: '${_points.length}'),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  if (!_recording)
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _start,
                        icon: const Icon(Icons.fiber_manual_record),
                        label: const Text(
                          'Demarrer',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _togglePause,
                        icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                        label: Text(_paused ? 'Reprendre' : 'Pause'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _stop,
                        icon: const Icon(Icons.stop),
                        label: const Text('Arreter & sauvegarder'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
        Text(
          value,
          style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
