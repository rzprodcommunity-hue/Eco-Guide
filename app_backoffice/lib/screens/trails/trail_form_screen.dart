import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;
import '../../core/providers/trails_provider.dart';
import '../../core/models/trail_model.dart';
import '../../core/models/poi_model.dart';
import '../../core/services/trail_service.dart';
import '../../core/services/poi_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_storage_service.dart';

class TrailFormScreen extends StatefulWidget {
  final String? trailId;

  const TrailFormScreen({super.key, this.trailId});

  @override
  State<TrailFormScreen> createState() => _TrailFormScreenState();
}

class _TrailFormScreenState extends State<TrailFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _elevationController = TextEditingController();
  final _regionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  TrailDifficulty _difficulty = TrailDifficulty.moderate;
  bool _isActive = true;
  Map<String, dynamic>? _geojson;
  List<String> _imageUrls = [];
  bool _isLoading = false;
  bool _isLoadingTrail = false;
  bool _isUploadingImage = false;
  bool _isLocating = false;
  LatLng? _markerLocation;

  // Trail video (single mp4 URL)
  String? _videoUrl;
  bool _isUploadingVideo = false;

  // POI selection
  List<PoiModel> _allPois = [];
  bool _isLoadingPois = false;
  final Set<String> _selectedPoiIds = {};
  Set<String> _initialPoiIds = {};

  // Auto-calc state
  bool _isComputingMetrics = false;

  // GPS recording state
  bool _isRecording = false;
  List<LatLng> _recordedPoints = [];
  StreamSubscription<Position>? _positionStream;
  final MapController _previewMapController = MapController();

  bool get isEditing => widget.trailId != null;

  @override
  void initState() {
    super.initState();
    _loadPois();
    if (isEditing) {
      _loadTrail();
    }
  }

  /// Load every POI once so the admin can attach/detach them from this trail.
  Future<void> _loadPois() async {
    setState(() => _isLoadingPois = true);
    try {
      final result = await PoiService.getPois(limit: 1000);
      final pois = (result['pois'] as List).cast<PoiModel>();
      if (!mounted) return;
      setState(() {
        _allPois = pois;
        // Pre-select POIs already attached to this trail (edit mode).
        if (isEditing) {
          for (final p in pois) {
            if (p.trailId == widget.trailId) {
              _selectedPoiIds.add(p.id);
            }
          }
          _initialPoiIds = Set<String>.from(_selectedPoiIds);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur chargement POIs: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoadingPois = false);
  }

  Future<void> _loadTrail() async {
    setState(() => _isLoadingTrail = true);
    try {
      final trail = await TrailService.getTrail(widget.trailId!);
      _nameController.text = trail.name;
      _descriptionController.text = trail.description;
      _distanceController.text = trail.distance.toString();
      _durationController.text = trail.estimatedDuration?.toString() ?? '';
      _elevationController.text = trail.elevationGain?.toString() ?? '';
      _regionController.text = trail.region ?? '';
      _latitudeController.text = trail.startLatitude?.toString() ?? '';
      _longitudeController.text = trail.startLongitude?.toString() ?? '';
      if (trail.startLatitude != null && trail.startLongitude != null) {
        _markerLocation =
            LatLng(trail.startLatitude!, trail.startLongitude!);
      }
      _difficulty = trail.difficulty;
      _isActive = trail.isActive;
      _geojson = trail.geojson;
      _imageUrls = trail.imageUrls ?? [];
      _videoUrl = trail.videoUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    setState(() => _isLoadingTrail = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _elevationController.dispose();
    _regionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  // ── GeoJSON helpers (sync recorded points → _geojson) ──────────────────

  Map<String, dynamic> _pointsToGeoJson(List<LatLng> points) {
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            // GeoJSON uses [longitude, latitude]
            'coordinates': points
                .map((p) => [p.longitude, p.latitude])
                .toList(),
          },
          'properties': {},
        },
      ],
    };
  }

  List<LatLng> _pointsFromGeoJson(Map<String, dynamic>? geojson) {
    final result = <LatLng>[];
    if (geojson == null) return result;
    try {
      final features = geojson['features'] as List?;
      if (features == null || features.isEmpty) return result;
      final geom = features.first['geometry'] as Map<String, dynamic>?;
      if (geom?['type'] != 'LineString') return result;
      final coords = geom?['coordinates'] as List?;
      if (coords == null) return result;
      for (final c in coords) {
        if (c is List && c.length >= 2) {
          result.add(LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ));
        }
      }
    } catch (_) {}
    return result;
  }

  void _syncRecordedToFields() {
    if (_recordedPoints.isEmpty) return;
    final km = _computeDistanceMeters(_recordedPoints) / 1000.0;
    setState(() {
      _geojson = _pointsToGeoJson(_recordedPoints);
      _latitudeController.text = _recordedPoints.first.latitude.toStringAsFixed(6);
      _longitudeController.text = _recordedPoints.first.longitude.toStringAsFixed(6);
      // Auto-fill the derived metrics ONLY when the field is still empty so we
      // never clobber a value the admin typed manually.
      if (_distanceController.text.trim().isEmpty) {
        _distanceController.text = km.toStringAsFixed(2);
      }
      if (_durationController.text.trim().isEmpty) {
        _durationController.text = _estimateDurationMinutes(km).toString();
      }
    });
  }

  double _computeDistanceMeters([List<LatLng>? pts]) {
    final points = pts ?? _recordedPoints;
    const Distance d = Distance();
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += d.as(LengthUnit.Meter, points[i], points[i + 1]);
    }
    return total;
  }

  /// Estimate the hiking duration (minutes) from distance, difficulty and
  /// ascent. Uses an average pace per difficulty plus Naismith's rule for the
  /// elevation gain (≈ +1 min per 10 m of climb) when a dénivelé is provided.
  int _estimateDurationMinutes(double distanceKm) {
    if (distanceKm <= 0) return 0;
    final speedKmh = switch (_difficulty) {
      TrailDifficulty.easy => 4.5,
      TrailDifficulty.moderate => 3.8,
      TrailDifficulty.difficult => 3.0,
    };
    double minutes = (distanceKm / speedKmh) * 60.0;
    final elev = double.tryParse(_elevationController.text.trim());
    if (elev != null && elev > 0) {
      minutes += elev / 10.0;
    }
    return minutes.round();
  }

  /// Returns the current track points (live recording or imported geojson).
  List<LatLng> _currentTrackPoints() => _recordedPoints.isNotEmpty
      ? _recordedPoints
      : _pointsFromGeoJson(_geojson);

  /// (Re)compute Distance (km), Dénivelé (m) and Estimated duration (min) from
  /// the track. Distance comes from the Haversine sum of the points, elevation
  /// gain from the track altitude (if present) or the Open-Meteo elevation API,
  /// and duration from Naismith's rule. The admin keeps full control: the
  /// fields stay editable afterwards.
  Future<void> _recalculateMetrics({bool showSnack = false}) async {
    final points = _currentTrackPoints();
    if (points.length < 2) {
      if (showSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucun tracé disponible pour le calcul.'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }

    setState(() => _isComputingMetrics = true);

    // 1) Distance (km) via Haversine sum.
    final km = _computeDistanceMeters(points) / 1000.0;
    if (mounted) {
      setState(() => _distanceController.text = km.toStringAsFixed(2));
    }

    // 2) Elevation gain (m). Try the track's own altitudes first; otherwise
    //    query the free Open-Meteo elevation API.
    int? gain = _elevationGainFromGeoJson();
    if (gain == null) {
      try {
        gain = await _fetchElevationGain(points);
      } catch (e) {
        if (showSnack && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Dénivelé non calculé (API): $e'),
            backgroundColor: AppColors.warning,
          ));
        }
      }
    }
    if (gain != null && mounted) {
      setState(() => _elevationController.text = gain.toString());
    }

    // 3) Duration (min) via Naismith's rule.
    final gainForDuration =
        gain ?? int.tryParse(_elevationController.text.trim()) ?? 0;
    final duration =
        ((km / 4.0 + gainForDuration / 600.0) * 60).round();
    if (mounted) {
      setState(() => _durationController.text = duration.toString());
    }

    if (mounted) setState(() => _isComputingMetrics = false);

    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Calculé : ${km.toStringAsFixed(2)} km'
          '${gain != null ? ' · ${gain}m D+' : ''} · ~$duration min',
        ),
        backgroundColor: AppColors.success,
      ));
    }
  }

  /// Sum positive consecutive altitude deltas if the GeoJSON LineString carries
  /// a 3rd (elevation) coordinate. Returns null when no altitude data exists.
  int? _elevationGainFromGeoJson() {
    try {
      final features = _geojson?['features'] as List?;
      if (features == null || features.isEmpty) return null;
      final geom = features.first['geometry'] as Map<String, dynamic>?;
      final coords = geom?['coordinates'] as List?;
      if (coords == null || coords.length < 2) return null;
      double gain = 0;
      bool hasAlt = false;
      double? prev;
      for (final c in coords) {
        if (c is List && c.length >= 3 && c[2] != null) {
          hasAlt = true;
          final alt = (c[2] as num).toDouble();
          if (prev != null && alt > prev) gain += alt - prev;
          prev = alt;
        }
      }
      if (!hasAlt) return null;
      return gain.round();
    } catch (_) {
      return null;
    }
  }

  /// Query the Open-Meteo elevation API for up to 100 evenly-spaced points and
  /// sum the positive consecutive deltas to get the total ascent (metres).
  Future<int> _fetchElevationGain(List<LatLng> points) async {
    // Down-sample to at most 100 evenly-spaced points.
    final sampled = <LatLng>[];
    const maxSamples = 100;
    if (points.length <= maxSamples) {
      sampled.addAll(points);
    } else {
      final step = (points.length - 1) / (maxSamples - 1);
      for (int i = 0; i < maxSamples; i++) {
        sampled.add(points[(i * step).round().clamp(0, points.length - 1)]);
      }
    }

    final lats = sampled.map((p) => p.latitude.toStringAsFixed(6)).join(',');
    final lngs = sampled.map((p) => p.longitude.toStringAsFixed(6)).join(',');
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/elevation'
      '?latitude=$lats&longitude=$lngs',
    );

    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final elevations = (json['elevation'] as List?)
        ?.map((e) => (e as num).toDouble())
        .toList();
    if (elevations == null || elevations.length < 2) {
      throw Exception('Données indisponibles');
    }
    double gain = 0;
    for (int i = 1; i < elevations.length; i++) {
      final delta = elevations[i] - elevations[i - 1];
      if (delta > 0) gain += delta;
    }
    return gain.round();
  }

  // ── Use current GPS position for start coordinates ─────────────────────

  Future<void> _useCurrentLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Activez la géolocalisation du navigateur.'),
          backgroundColor: AppColors.error,
        ));
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Permission de localisation refusée.'),
          backgroundColor: AppColors.error,
        ));
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitudeController.text = pos.latitude.toStringAsFixed(6);
        _longitudeController.text = pos.longitude.toStringAsFixed(6);
        _markerLocation = LatLng(pos.latitude, pos.longitude);
      });
      messenger.showSnackBar(const SnackBar(
        content: Text('Position actuelle récupérée.'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Erreur de localisation: $e'),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // ── GPS recording ──────────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final messenger = ScaffoldMessenger.of(context);

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Activez la géolocalisation du navigateur.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Permission de localisation refusée.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() {
      _isRecording = true;
      _recordedPoints = []; // start fresh
    });

    // Capture initial position immediately
    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      if (mounted) {
        setState(() {
          _recordedPoints
              .add(LatLng(initial.latitude, initial.longitude));
        });
        _previewMapController.move(
          LatLng(initial.latitude, initial.longitude), 16);
      }
    } catch (_) {}

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2, // record every 2 meters
      ),
    ).listen((pos) {
      if (!mounted) return;
      final newPoint = LatLng(pos.latitude, pos.longitude);
      // Skip if too close to last point (extra jitter filter)
      if (_recordedPoints.isNotEmpty) {
        const d = Distance();
        final m = d.as(LengthUnit.Meter, _recordedPoints.last, newPoint);
        if (m < 1.5) return;
      }
      setState(() {
        _recordedPoints.add(newPoint);
      });
    });
  }

  Future<void> _stopRecording() async {
    await _positionStream?.cancel();
    _positionStream = null;
    setState(() => _isRecording = false);
    _syncRecordedToFields();
    if (mounted && _recordedPoints.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Enregistrement terminé : ${_recordedPoints.length} points '
          '(${_computeDistanceMeters().toStringAsFixed(0)} m)',
        ),
        backgroundColor: AppColors.success,
      ));
    }
  }

  void _clearRecording() {
    _positionStream?.cancel();
    _positionStream = null;
    setState(() {
      _isRecording = false;
      _recordedPoints = [];
      _geojson = null;
    });
  }

  // ── GPX import ─────────────────────────────────────────────────────────

  Future<void> _importGpx() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx', 'xml'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    try {
      final content = utf8.decode(result.files.single.bytes!);
      final points = _parseGpxTrackPoints(content);
      if (points.isEmpty) {
        throw Exception('Aucun point trouvé dans le GPX');
      }
      setState(() {
        _recordedPoints = points;
        _geojson = _pointsToGeoJson(points);
      });
      _syncRecordedToFields();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('GPX importé : ${points.length} points'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur GPX : $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  List<LatLng> _parseGpxTrackPoints(String xml) {
    final points = <LatLng>[];
    // Match both <trkpt> (track) and <rtept> (route) and <wpt> (waypoint)
    final regex = RegExp(
      r'<(?:trkpt|rtept|wpt)\s+[^>]*?lat\s*=\s*"([-\d.]+)"\s+lon\s*=\s*"([-\d.]+)"',
      caseSensitive: false,
    );
    for (final match in regex.allMatches(xml)) {
      final lat = double.tryParse(match.group(1) ?? '');
      final lon = double.tryParse(match.group(2) ?? '');
      if (lat != null && lon != null) {
        points.add(LatLng(lat, lon));
      }
    }
    return points;
  }

  // ── GPX export ─────────────────────────────────────────────────────────

  String _buildGpxXml(List<LatLng> points, String trackName) {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<gpx version="1.1" creator="EcoGuide" '
        'xmlns="http://www.topografix.com/GPX/1/1">');
    buf.writeln('  <trk>');
    buf.writeln('    <name>${_xmlEscape(trackName)}</name>');
    buf.writeln('    <trkseg>');
    for (final p in points) {
      buf.writeln('      <trkpt lat="${p.latitude.toStringAsFixed(6)}" '
          'lon="${p.longitude.toStringAsFixed(6)}"/>');
    }
    buf.writeln('    </trkseg>');
    buf.writeln('  </trk>');
    buf.writeln('</gpx>');
    return buf.toString();
  }

  String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ── Tracking UI ────────────────────────────────────────────────────────

  Widget _buildTrackingControls() {
    final pointCount = _recordedPoints.isNotEmpty
        ? _recordedPoints.length
        : _pointsFromGeoJson(_geojson).length;
    final hasTrack = pointCount > 0;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Record / Stop button (primary)
        ElevatedButton.icon(
          onPressed: _toggleRecording,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _isRecording ? AppColors.error : AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          icon: Icon(_isRecording
              ? Icons.stop_circle_outlined
              : Icons.fiber_manual_record),
          label: Text(_isRecording
              ? 'Arrêter l\'enregistrement'
              : 'Démarrer enregistrement GPS'),
        ),

        // Import GPX
        OutlinedButton.icon(
          onPressed: _isRecording ? null : _importGpx,
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('Importer GPX'),
        ),

        // Export GPX
        OutlinedButton.icon(
          onPressed: hasTrack && !_isRecording ? _exportGpx : null,
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Exporter GPX'),
        ),

        // Import GeoJSON (kept for backwards compat)
        OutlinedButton.icon(
          onPressed: _isRecording ? null : _pickGeoJson,
          icon: const Icon(Icons.code),
          label: const Text('Importer GeoJSON'),
        ),

        // Clear
        if (hasTrack && !_isRecording)
          TextButton.icon(
            onPressed: _clearRecording,
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            label: const Text('Effacer',
                style: TextStyle(color: AppColors.error)),
          ),

        // Status chip
        if (_isRecording)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'REC · ${_recordedPoints.length} pts · '
                  '${_computeDistanceMeters().toStringAsFixed(0)} m',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else if (hasTrack)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.success, size: 16),
                const SizedBox(width: 6),
                Text(
                  '$pointCount points enregistrés',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLocationMap() {
    if (_markerLocation == null) {
      final onSurface = Theme.of(context).colorScheme.onSurface;
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined,
                  size: 48, color: onSurface.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              Text(
                'Appuyez sur « Utiliser ma position GPS » pour afficher\nvotre position sur la carte',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: onSurface.withValues(alpha: 0.6), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final loc = _markerLocation!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 280,
        child: FlutterMap(
          key: ValueKey('${loc.latitude},${loc.longitude}'),
          options: MapOptions(initialCenter: loc, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ecoguide.backoffice',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: loc,
                  width: 44,
                  height: 44,
                  child: const Icon(
                    Icons.location_pin,
                    color: AppColors.error,
                    size: 44,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewMap() {
    final points = _recordedPoints.isNotEmpty
        ? _recordedPoints
        : _pointsFromGeoJson(_geojson);

    if (points.isEmpty) {
      final onSurface = Theme.of(context).colorScheme.onSurface;
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined,
                  size: 48, color: onSurface.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              Text(
                'Aucun tracé pour le moment',
                style: TextStyle(color: onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 4),
              Text(
                'Démarrez l\'enregistrement GPS ou importez un fichier',
                style: TextStyle(
                    color: onSurface.withValues(alpha: 0.5), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final bounds =
        points.length > 1 ? LatLngBounds.fromPoints(points) : null;
    final initialCenter = points.first;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 320,
        child: FlutterMap(
          mapController: _previewMapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 16,
            initialCameraFit: bounds != null
                ? CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(40),
                  )
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              userAgentPackageName: 'com.ecoguide.backoffice',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 4,
                  color: AppColors.primary,
                  borderStrokeWidth: 1,
                  borderColor: Colors.white,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: points.first,
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 18),
                  ),
                ),
                if (points.length > 1)
                  Marker(
                    point: points.last,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? AppColors.error
                            : AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Icon(
                        _isRecording ? Icons.my_location : Icons.flag,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportGpx() async {
    final points = _recordedPoints.isNotEmpty
        ? _recordedPoints
        : _pointsFromGeoJson(_geojson);
    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucun tracé à exporter.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'sentier';
    final xml = _buildGpxXml(points, name);

    if (kIsWeb) {
      // Trigger browser download
      final bytes = utf8.encode(xml);
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'application/gpx+xml'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = '${name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.gpx';
      anchor.click();
      web.URL.revokeObjectURL(url);
    } else {
      // Non-web fallback: copy to clipboard
      // (backoffice runs on web, so this branch is rarely hit)
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('GPX exporté (${points.length} points)'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _pickGeoJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'geojson'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      try {
        final content = utf8.decode(result.files.single.bytes!);
        final json = jsonDecode(content);
        if (!mounted) return;
        setState(() {
          _geojson = json;
          _recordedPoints = _pointsFromGeoJson(json);
        });
        // Auto-fill start coordinates + distance/duration from the track.
        _syncRecordedToFields();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GeoJSON importe avec succes')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur: Fichier GeoJSON invalide'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Upload an image to the backend media service and add the URL to the list
  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;
    setState(() => _isUploadingImage = true);

    try {
      final ext = file.name.split('.').last.toLowerCase();
      final contentType = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final url = await SupabaseStorageService.uploadBytes(
        bucket: 'images',
        fileName: file.name,
        bytes: file.bytes!,
        contentType: contentType,
      );
      setState(() {
        _imageUrls.add(url);
        _isUploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploadée avec succès!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur upload: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageUrls.removeAt(index);
    });
  }

  /// Pick + upload a single MP4 video (max 100 MB) to Supabase storage.
  Future<void> _pickAndUploadVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;
    final isMp4 = file.name.toLowerCase().endsWith('.mp4');
    final tooBig = file.bytes!.length > 100 * 1024 * 1024;
    if (!isMp4 || tooBig) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!isMp4
                ? 'Format invalide : seul le MP4 est accepté.'
                : 'La vidéo dépasse 100 Mo.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isUploadingVideo = true);
    try {
      final url = await SupabaseStorageService.uploadVideo(
        fileName: file.name,
        bytes: file.bytes!,
      );
      if (!mounted) return;
      setState(() {
        _videoUrl = url;
        _isUploadingVideo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vidéo uploadée avec succès!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingVideo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur upload vidéo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'distance': double.parse(_distanceController.text),
      'difficulty': _difficulty.name,
      'estimatedDuration': _durationController.text.isNotEmpty
          ? int.parse(_durationController.text)
          : null,
      'elevationGain': _elevationController.text.isNotEmpty
          ? int.parse(_elevationController.text)
          : null,
      'region': _regionController.text.trim().isNotEmpty
          ? _regionController.text.trim()
          : null,
      'startLatitude': _latitudeController.text.isNotEmpty
          ? double.parse(_latitudeController.text)
          : null,
      'startLongitude': _longitudeController.text.isNotEmpty
          ? double.parse(_longitudeController.text)
          : null,
      'geojson': _geojson,
      'imageUrls': _imageUrls,
      'videoUrl': _videoUrl,
      'isActive': _isActive,
    };

    final provider = context.read<TrailsProvider>();

    try {
      // Persist the trail directly so we can read back the new id; then refresh
      // the provider list so the table stays in sync.
      String trailId;
      if (isEditing) {
        await TrailService.updateTrail(widget.trailId!, data);
        trailId = widget.trailId!;
      } else {
        final created = await TrailService.createTrail(data);
        trailId = created.id;
      }

      // Reconcile POI assignments. api_service strips nulls, so detaching a POI
      // (trailId -> null) must go through Supabase directly.
      await _reconcilePoiAssignments(trailId);

      await provider.loadTrails(page: provider.currentPage);

      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Sentier modifie' : 'Sentier cree'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/trails');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Attach newly-selected POIs to this trail and detach the ones removed.
  Future<void> _reconcilePoiAssignments(String trailId) async {
    final sb = Supabase.instance.client;
    // Attach: selected but not originally on this trail.
    for (final id in _selectedPoiIds) {
      if (!_initialPoiIds.contains(id)) {
        await sb.from('pois').update({'trailId': trailId}).eq('id', id);
      }
    }
    // Detach: originally on this trail but now deselected.
    for (final id in _initialPoiIds) {
      if (!_selectedPoiIds.contains(id)) {
        await sb.from('pois').update({'trailId': null}).eq('id', id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTrail) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/trails'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'Modifier le sentier' : 'Nouveau sentier',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('Informations generales', [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nom du sentier',
                      validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      maxLines: 4,
                      validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _regionController,
                      label: 'Region',
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Images du sentier', [
                    _buildImageUploadSection(),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Caracteristiques', [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _distanceController,
                            label: 'Distance (km)',
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v?.isEmpty == true ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _durationController,
                            label: 'Duree estimee (min)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _elevationController,
                            label: 'Denivele (m)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildAutoMetricsHint(),
                    const SizedBox(height: 16),
                    _buildDifficultyDropdown(),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Coordonnees de depart', [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _latitudeController,
                            label: 'Latitude',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _longitudeController,
                            label: 'Longitude',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _isLocating ? null : _useCurrentLocation,
                        icon: _isLocating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location, size: 18),
                        label: Text(_isLocating
                            ? 'Localisation...'
                            : 'Utiliser ma position GPS'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLocationMap(),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Tracé du sentier', [
                    _buildTrackingControls(),
                    const SizedBox(height: 16),
                    _buildPreviewMap(),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Points d\'intérêt du sentier', [
                    _buildPoiSelectionSection(),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Statut', [
                    SwitchListTile(
                      title: const Text('Sentier actif'),
                      subtitle: const Text(
                        'Les sentiers inactifs ne sont pas visibles',
                      ),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      activeThumbColor: AppColors.primary,
                    ),
                  ]),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => context.go('/trails'),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(isEditing ? 'Enregistrer' : 'Creer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the image upload section with preview gallery and upload button
  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ajoutez des photos pour illustrer ce sentier',
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Existing image thumbnails
            ..._imageUrls.asMap().entries.map((entry) {
              final index = entry.key;
              final url = entry.value;
              return _buildImageThumbnail(url, index);
            }),
            // Upload button
            _buildUploadButton(),
          ],
        ),
        if (_imageUrls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_imageUrls.length} image${_imageUrls.length > 1 ? 's' : ''} ajoutée${_imageUrls.length > 1 ? 's' : ''}',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 20),
        _buildVideoUploadSection(),
      ],
    );
  }

  /// Single-MP4 video upload row + current-video chip.
  Widget _buildVideoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vidéo du sentier',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Une vidéo MP4 (100 Mo max) pour présenter le sentier',
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _isUploadingVideo ? null : _pickAndUploadVideo,
          icon: _isUploadingVideo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.videocam_outlined, size: 18),
          label: Text(_isUploadingVideo
              ? 'Téléversement...'
              : 'Ajouter une vidéo (MP4, max 100 Mo)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        if (_videoUrl != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.movie_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _videoUrl!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _videoUrl = null),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Checkbox list to attach/detach POIs to/from this trail.
  Widget _buildPoiSelectionSection() {
    if (_isLoadingPois) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_allPois.isEmpty) {
      return Text(
        'Aucun point d\'intérêt disponible.',
        style: TextStyle(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cochez les points d\'intérêt qui font partie de ce sentier '
          '(${_selectedPoiIds.length} sélectionné${_selectedPoiIds.length > 1 ? 's' : ''}).',
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 320),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _allPois.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: Theme.of(context).dividerColor),
            itemBuilder: (context, i) {
              final poi = _allPois[i];
              final selected = _selectedPoiIds.contains(poi.id);
              final attachedElsewhere =
                  poi.trailId != null && poi.trailId != widget.trailId;
              return CheckboxListTile(
                value: selected,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedPoiIds.add(poi.id);
                  } else {
                    _selectedPoiIds.remove(poi.id);
                  }
                }),
                activeColor: AppColors.primary,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text(
                  poi.name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  attachedElsewhere && !selected
                      ? '${poi.typeLabel} · déjà rattaché à un autre sentier'
                      : poi.typeLabel,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(String url, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: 110,
            height: 110,
            fit: BoxFit.cover,
            errorBuilder: (_, e, s) => Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: AppColors.textHint, size: 28),
                  SizedBox(height: 4),
                  Text(
                    'Erreur',
                    style: TextStyle(fontSize: 10, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Delete button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
        // Index badge
        if (index == 0)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Principale',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUploadButton() {
    return GestureDetector(
      onTap: _isUploadingImage ? null : _pickAndUploadImage,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: _isUploadingImage
            ? const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppColors.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ajouter',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildAutoMetricsHint() {
    final hasTrack = _currentTrackPoints().length > 1;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Distance, dénivelé et durée sont calculés automatiquement à '
              'partir du tracé GPS. Vous pouvez les ajuster manuellement.',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: (hasTrack && !_isComputingMetrics)
                ? () => _recalculateMetrics(showSnack: true)
                : null,
            icon: _isComputingMetrics
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.calculate_outlined, size: 18),
            label: Text(_isComputingMetrics
                ? 'Calcul...'
                : 'Recalculer automatiquement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyDropdown() {
    return DropdownButtonFormField<TrailDifficulty>(
      initialValue: _difficulty,
      decoration: InputDecoration(
        labelText: 'Difficulte',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: TrailDifficulty.values.map((d) {
        return DropdownMenuItem(
          value: d,
          child: Text(
            d == TrailDifficulty.easy
                ? 'Facile'
                : d == TrailDifficulty.moderate
                ? 'Modere'
                : 'Difficile',
          ),
        );
      }).toList(),
      onChanged: (v) =>
          setState(() => _difficulty = v ?? TrailDifficulty.moderate),
    );
  }
}
