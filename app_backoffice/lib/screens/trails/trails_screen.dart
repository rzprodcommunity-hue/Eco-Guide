import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../../core/providers/trails_provider.dart';
import '../../core/models/trail_model.dart';
import '../../core/models/poi_model.dart';
import '../../core/services/poi_service.dart';
import '../../core/services/trail_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/responsive.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_storage_service.dart';

class TrailsScreen extends StatefulWidget {
  const TrailsScreen({super.key});

  @override
  State<TrailsScreen> createState() => _TrailsScreenState();
}

class _TrailsScreenState extends State<TrailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _distanceController = TextEditingController();
  final _elevationController = TextEditingController();
  final _durationController = TextEditingController();
  final _regionController = TextEditingController();
  final _searchController = TextEditingController();

  TrailDifficulty _difficulty = TrailDifficulty.moderate;
  bool _isActive = true;
  bool _isSaving = false;
  String? _editingId;
  Map<String, dynamic>? _geojson;
  LatLng _mapCenter = const LatLng(
    37.113,
    9.023,
  ); // Jbel Chitana, Nefza, Tunisia
  List<LatLng> _drawnPoints = [];
  final _scrollController = ScrollController();
  final _formSectionKey = GlobalKey();
  final MapController _mapController = MapController();
  final TextEditingController _mapSearchController = TextEditingController();
  bool _isSearchingMap = false;
  bool _isLocating = false;
  LatLng? _myLocation;

  List<String> _imageUrls = [];
  bool _isUploadingImage = false;

  // POI selection — a POI belongs to at most ONE trail (pois.trailId).
  List<PoiModel> _allPois = [];
  final Set<String> _selectedPoiIds = {};
  Set<String> _initialPoiIds = {};
  bool _isLoadingPois = false;

  // Client-side pagination of the existing-trails list.
  int _listPage = 0;
  static const int _pageSize = 5;

  // Auto metrics (distance + elevation)
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrailsProvider>().loadTrails();
      _loadAllPois();
      _autoLocate();
    });
  }

  /// Quickly centers the map on the user's current position when creating a
  /// new trail: a last-known fix first (instant), then a fresh fix.
  Future<void> _autoLocate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      void apply(Position pos, double zoom) {
        // Don't fight the user: skip once editing or a track is being drawn.
        if (!mounted || _editingId != null || _drawnPoints.isNotEmpty) return;
        final p = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _myLocation = p;
          _mapCenter = p;
        });
        try {
          _mapController.move(p, zoom);
        } catch (_) {}
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) apply(last, 14);

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      apply(pos, 15);
    } catch (_) {
      // Best-effort convenience; ignore failures silently.
    }
  }

  /// Loads every POI so the trail form can show a selectable list and know
  /// which POIs are already attached to the trail being edited.
  Future<void> _loadAllPois() async {
    setState(() => _isLoadingPois = true);
    try {
      final res = await PoiService.getPois(limit: 1000);
      if (!mounted) return;
      setState(() {
        _allPois = res['pois'] as List<PoiModel>;
        // If we are editing a trail, (re)compute which POIs belong to it now
        // that the list is available.
        if (_editingId != null) {
          _selectedPoiIds
            ..clear()
            ..addAll(
              _allPois.where((p) => p.trailId == _editingId).map((p) => p.id),
            );
          _initialPoiIds = Set<String>.from(_selectedPoiIds);
        }
      });
    } catch (_) {
      // Non-fatal: the POI picker just stays empty.
    } finally {
      if (mounted) setState(() => _isLoadingPois = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _distanceController.dispose();
    _elevationController.dispose();
    _durationController.dispose();
    _regionController.dispose();
    _searchController.dispose();
    _mapSearchController.dispose();
    _scrollController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── Auto metrics (distance + elevation) ─────────────────────────────────

  double _trackDistanceKm() {
    const d = Distance();
    double meters = 0;
    for (int i = 0; i < _drawnPoints.length - 1; i++) {
      meters += d.as(LengthUnit.Meter, _drawnPoints[i], _drawnPoints[i + 1]);
    }
    return meters / 1000.0;
  }

  /// Refresh the Distance field from the drawn track. Called automatically on
  /// every new point so the value is always up to date (the admin can still
  /// edit it manually once the track is finished).
  void _recomputeDistanceField() {
    if (_drawnPoints.isEmpty) {
      _distanceController.text = '';
    } else if (_drawnPoints.length < 2) {
      _distanceController.text = '0.0';
    } else {
      _distanceController.text = _trackDistanceKm().toStringAsFixed(2);
    }
  }

  /// Compute Distance (km) + Elevation gain (m) from the track. Distance is
  /// computed locally; the elevation gain is fetched from the Open-Meteo
  /// terrain elevation API (drawn points carry no altitude).
  Future<void> _calculateMetrics() async {
    if (_drawnPoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tracez au moins 2 points pour calculer.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    setState(() => _isCalculating = true);

    final km = _trackDistanceKm();
    _distanceController.text = km.toStringAsFixed(2);

    int? gain;
    try {
      gain = await _fetchElevationGain(_drawnPoints);
      if (gain != null) _elevationController.text = gain.toString();
    } catch (_) {
      // Keep the distance even if the elevation lookup fails.
    }

    // Estimated duration (Naismith's rule): ~1h per 4 km of walking plus
    // ~1h per 600 m of ascent. The admin can still override the value.
    final gForDuration = gain ?? int.tryParse(_elevationController.text) ?? 0;
    final minutes = ((km / 4.0) + (gForDuration / 600.0)) * 60.0;
    _durationController.text = minutes.round().toString();

    if (!mounted) return;
    setState(() => _isCalculating = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(gain != null
          ? 'Calculé : ${km.toStringAsFixed(2)} km · +$gain m · '
              '${minutes.round()} min'
          : 'Distance ${km.toStringAsFixed(2)} km · ${minutes.round()} min '
              '(dénivelé indisponible).'),
      backgroundColor: gain != null ? AppColors.success : AppColors.warning,
    ));
  }

  /// Fetch terrain elevations for the points and sum the positive deltas.
  Future<int?> _fetchElevationGain(List<LatLng> pts) async {
    final elevations = <double>[];
    const chunk = 100; // Open-Meteo allows up to 100 coordinates per request
    for (int i = 0; i < pts.length; i += chunk) {
      final end = (i + chunk) < pts.length ? (i + chunk) : pts.length;
      final sub = pts.sublist(i, end);
      final lats = sub.map((p) => p.latitude.toStringAsFixed(6)).join(',');
      final lons = sub.map((p) => p.longitude.toStringAsFixed(6)).join(',');
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/elevation?latitude=$lats&longitude=$lons',
      );
      final resp = await http.get(url);
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final elev = data['elevation'] as List?;
      if (elev == null) return null;
      elevations.addAll(elev.map((e) => (e as num).toDouble()));
    }
    if (elevations.length < 2) return null;
    double gain = 0;
    for (int i = 1; i < elevations.length; i++) {
      final diff = elevations[i] - elevations[i - 1];
      if (diff > 0) gain += diff;
    }
    return gain.round();
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service de localisation désactivé'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission de localisation refusée'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
    return true;
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
      if (points.isEmpty) throw Exception('Aucun point trouvé dans le GPX');
      setState(() {
        _drawnPoints = points;
        _geojson = null;
      });
      _recomputeDistanceField();
      if (points.isNotEmpty) {
        _mapController.move(points.first, 14);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPX importé : ${points.length} points'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur GPX : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<LatLng> _parseGpxTrackPoints(String xml) {
    final points = <LatLng>[];
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

  Future<void> _exportGpx() async {
    if (_drawnPoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun tracé à exporter'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final name =
        _nameController.text.trim().isEmpty ? 'trail' : _nameController.text.trim();
    final xml = _buildGpxXml(_drawnPoints, name);

    if (kIsWeb) {
      final blob = web.Blob(
        [xml.toJS].toJS,
        web.BlobPropertyBag(type: 'application/gpx+xml'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download =
            '${name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.gpx';
      anchor.click();
      web.URL.revokeObjectURL(url);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GPX exporté (${_drawnPoints.length} points)'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

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

  void _editTrail(TrailModel trail) {
    setState(() {
      _editingId = trail.id;
      _nameController.text = trail.name;
      _descriptionController.text = trail.description;
      _distanceController.text = trail.distance.toString();
      _elevationController.text = trail.elevationGain?.toString() ?? '';
      _durationController.text = trail.estimatedDuration?.toString() ?? '';
      _regionController.text = trail.region ?? '';
      _difficulty = trail.difficulty;
      _isActive = trail.isActive;
      _geojson = trail.geojson;
      _drawnPoints.clear();

      // Pre-select the POIs already attached to this trail.
      _selectedPoiIds
        ..clear()
        ..addAll(_allPois.where((p) => p.trailId == trail.id).map((p) => p.id));
      _initialPoiIds = Set<String>.from(_selectedPoiIds);

      if (trail.startLatitude != null && trail.startLongitude != null) {
        _mapCenter = LatLng(trail.startLatitude!, trail.startLongitude!);
      }

      if (trail.geojson != null) {
        try {
          final features = trail.geojson!['features'] as List;
          if (features.isNotEmpty) {
            final geometry = features[0]['geometry'];
            if (geometry['type'] == 'LineString') {
              final coords = geometry['coordinates'] as List;
              for (var coord in coords) {
                _drawnPoints.add(LatLng(coord[1], coord[0]));
              }
            }
          }
        } catch (_) {}
      }
      _imageUrls = trail.imageUrls ?? [];
    });

    // Scroll the form into view so the admin sees the populated fields.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_formSectionKey.currentContext != null) {
        Scrollable.ensureVisible(
          _formSectionKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Modification de « ${trail.name} » — modifiez puis enregistrez.',
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _descriptionController.clear();
      _distanceController.clear();
      _elevationController.clear();
      _durationController.clear();
      _selectedPoiIds.clear();
      _initialPoiIds = {};
      _regionController.clear();
      _difficulty = TrailDifficulty.moderate;
      _isActive = true;
      _geojson = null;
      _drawnPoints.clear();
      _imageUrls = [];
      _mapCenter = const LatLng(37.113, 9.023);
    });
    // Scroll to form section
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_formSectionKey.currentContext != null) {
        Scrollable.ensureVisible(
          _formSectionKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _searchMapLocation() async {
    final query = _mapSearchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearchingMap = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'EcoGuideApp'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final newCenter = LatLng(lat, lon);

          _mapController.move(newCenter, 14.0);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lieu trouvé !'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lieu introuvable'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur de recherche'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingMap = false);
      }
    }
  }

  // ── Show my current location on the map ────────────────────────────────
  Future<void> _useMyLocation() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return;

    setState(() => _isLocating = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final p = LatLng(pos.latitude, pos.longitude);
      setState(() => _myLocation = p);
      _mapController.move(p, 16);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position actuelle récupérée.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de localisation: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _saveTrail({bool asDraft = false}) async {
    if (!_formKey.currentState!.validate()) {
      // Validation failed: bring the form (with its red error fields) back into
      // view and show an explicit error notification.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_formSectionKey.currentContext != null) {
          Scrollable.ensureVisible(
            _formSectionKey.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Veuillez corriger les champs en rouge avant d\'enregistrer.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      return;
    }
    setState(() => _isSaving = true);

    try {
      final provider = context.read<TrailsProvider>();
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : 'No description provided',
        'distance': double.tryParse(_distanceController.text) ?? 0.1,
        'difficulty': _difficulty.name,
        'isActive': asDraft ? false : _isActive,
      };

      if (_drawnPoints.length > 1) {
        final coordinates = _drawnPoints
            .map((p) => [p.longitude, p.latitude])
            .toList();
        data['geojson'] = {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "LineString", "coordinates": coordinates},
              "properties": {"name": _nameController.text.trim()},
            },
          ],
        };
      } else if (_geojson != null) {
        data['geojson'] = _geojson;
      }

      data['startLatitude'] = _drawnPoints.isNotEmpty
          ? _drawnPoints.first.latitude
          : _mapCenter.latitude;
      data['startLongitude'] = _drawnPoints.isNotEmpty
          ? _drawnPoints.first.longitude
          : _mapCenter.longitude;

      // Only add optional fields if they have values
      if (_elevationController.text.isNotEmpty) {
        data['elevationGain'] = int.tryParse(_elevationController.text);
      }
      if (_durationController.text.isNotEmpty) {
        data['estimatedDuration'] = int.tryParse(_durationController.text);
      }
      if (_regionController.text.trim().isNotEmpty) {
        data['region'] = _regionController.text.trim();
      }
      data['imageUrls'] = _imageUrls;

      // Save through the service directly so we obtain the trail id (needed to
      // attach/detach POIs). Errors throw and are handled by the catch below.
      final wasEditing = _editingId != null;
      final TrailModel saved;
      if (wasEditing) {
        saved = await TrailService.updateTrail(_editingId!, data);
      } else {
        saved = await TrailService.createTrail(data);
      }
      await _reconcilePoiAssignments(saved.id);
      await provider.loadTrails(page: provider.currentPage);

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasEditing ? 'Sentier mis à jour !' : 'Sentier enregistré !',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _resetForm();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Erreur'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _deleteTrail(TrailModel trail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Supprimer le sentier'),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer « ${trail.name} » ? '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              'Annuler',
              style: TextStyle(
                color: Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final provider = context.read<TrailsProvider>();
      final ok = await provider.deleteTrail(trail.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Sentier supprimé'
                : 'Échec de la suppression : ${provider.error}',
          ),
          backgroundColor: ok ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

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
            content: Text('Image téléversée avec succès !'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de téléversement : $e'),
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

  // ── POI ↔ trail reconciliation ──────────────────────────────────────────

  /// Attaches newly-selected POIs to this trail and detaches removed ones.
  /// Goes through Supabase directly so detaching (trailId -> null) is honored
  /// (the api_service layer strips null values from payloads).
  Future<void> _reconcilePoiAssignments(String trailId) async {
    final sb = Supabase.instance.client;
    for (final id in _selectedPoiIds) {
      if (!_initialPoiIds.contains(id)) {
        await sb.from('pois').update({'trailId': trailId}).eq('id', id);
      }
    }
    for (final id in _initialPoiIds) {
      if (!_selectedPoiIds.contains(id)) {
        await sb.from('pois').update({'trailId': null}).eq('id', id);
      }
    }
    await _loadAllPois();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrailsProvider>();

    final isCompact = Responsive.isCompact(context);

    final headerTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestion des sentiers',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Créez, surveillez et mettez à jour les itinéraires de randonnée à travers l\'écosystème.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );

    final createButton = ElevatedButton.icon(
      onPressed: _resetForm,
      icon: const Icon(Icons.add),
      label: const Text('Créer un nouveau sentier'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
      ),
    );

    return SingleChildScrollView(
      controller: _scrollController,
      padding: Responsive.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerTitle,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: createButton),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [headerTitle, createButton],
            ),
          const SizedBox(height: 24),

          // Stats Cards
          _buildStatsRow(provider),
          const SizedBox(height: 24),

          // Form (full width) + Save button
          Column(
            key: _formSectionKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTrailDetailsForm(),
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ),
          const SizedBox(height: 32),

          // Existing Trails Table
          _buildExistingTrailsTable(provider),
        ],
      ),
    );
  }

  // ── Stats Row ────────────────────────────────────────
  Widget _buildStatsRow(TrailsProvider provider) {
    double totalDistance = 0;
    int easyCount = 0, modCount = 0, diffCount = 0;
    for (var t in provider.trails) {
      totalDistance += t.distance;
      if (t.difficulty == TrailDifficulty.easy) easyCount++;
      if (t.difficulty == TrailDifficulty.moderate) modCount++;
      if (t.difficulty == TrailDifficulty.difficult) diffCount++;
    }
    String avgDiff = 'Modérée';
    if (easyCount >= modCount && easyCount >= diffCount) avgDiff = 'Facile';
    if (diffCount >= modCount && diffCount >= easyCount) avgDiff = 'Difficile';

    final cards = [
      _statCard(
        'Total des sentiers',
        provider.total.toString(),
        Icons.terrain,
        AppColors.primary,
      ),
      _statCard('Randonneurs actifs', '1 284', Icons.people, Colors.blue),
      _statCard(
        'Distance totale',
        '${totalDistance.toStringAsFixed(0)} km',
        Icons.straighten,
        Colors.teal,
      ),
      _statCard(
        'Difficulté moyenne',
        avgDiff,
        Icons.signal_cellular_alt,
        Colors.orange,
      ),
    ];

    final crossAxisCount =
        Responsive.value(context, mobile: 2, tablet: 2, desktop: 4);

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final itemWidth = (constraints.maxWidth -
                spacing * (crossAxisCount - 1)) /
            crossAxisCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((c) => SizedBox(width: itemWidth, child: c))
              .toList(),
        );
      },
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ── Trail Details Form ───────────────────────────────
  Widget _buildTrailDetailsForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editingId != null ? 'Modifier le sentier' : 'Détails du sentier',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Trail Name + Difficulty
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du sentier',
                      hintText: 'ex. Boucle de Pine Ridge',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<TrailDifficulty>(
                    value: _difficulty,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Niveau de difficulté',
                      border: OutlineInputBorder(),
                    ),
                    items: TrailDifficulty.values.map((d) {
                      String label = d == TrailDifficulty.easy
                          ? 'Facile'
                          : d == TrailDifficulty.moderate
                          ? 'Modérée'
                          : 'Difficile';
                      return DropdownMenuItem(value: d, child: Text(label));
                    }).toList(),
                    onChanged: (v) => setState(
                      () => _difficulty = v ?? TrailDifficulty.moderate,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Décrivez le terrain, les vues et les conseils de sécurité...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Images
            _buildImageUploadSection(),
            const SizedBox(height: 24),

            // Distance + Elevation
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Distance (km)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _distanceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '0.0',
                        ),
                        validator: (v) =>
                            v?.isEmpty == true ? 'Requis' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dénivelé (m)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _elevationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '0',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Estimated duration — auto-calculated, still editable.
            const Text(
              'Durée estimée (min)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'ex. 120',
              ),
            ),
            const SizedBox(height: 12),
            _buildAutoMetricsRow(),
            const SizedBox(height: 24),

            // Points of interest attached to this trail.
            _buildPoiSelectionSection(),
            const SizedBox(height: 24),

            // Route Path
            const Text(
              'Tracé du sentier',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Touchez la carte pour ajouter des points au tracé.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _importGpx,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Importer GPX'),
                ),
                OutlinedButton.icon(
                  onPressed: _drawnPoints.length >= 2 ? _exportGpx : null,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Exporter GPX'),
                ),
                if (_drawnPoints.isNotEmpty) ...[
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _drawnPoints.removeLast());
                      _recomputeDistanceField();
                    },
                    icon: const Icon(
                      Icons.undo,
                      size: 18,
                      color: Colors.orange,
                    ),
                    label: const Text(
                      'Annuler',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _drawnPoints.clear());
                      _recomputeDistanceField();
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.error,
                    ),
                    label: const Text(
                      'Effacer le tracé',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Map Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mapSearchController,
                    decoration: InputDecoration(
                      hintText: 'Chercher un lieu (ex: Jbel Chitana)...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onSubmitted: (_) => _searchMapLocation(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSearchingMap ? null : _searchMapLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  child: _isSearchingMap
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Aller'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 600,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _mapCenter,
                        initialZoom: 14.0,
                        onTap: (tapPosition, point) {
                          setState(() => _drawnPoints.add(point));
                          _recomputeDistanceField();
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
                          userAgentPackageName: 'com.ecoguide.app',
                        ),
                        PolylineLayer(
                          polylines: [
                            if (_drawnPoints.length > 1)
                              Polyline(
                                points: _drawnPoints,
                                color: AppColors.error,
                                strokeWidth: 4.0,
                              ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            ..._drawnPoints.map(
                              (p) => Marker(
                                point: p,
                                width: 12,
                                height: 12,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            if (_drawnPoints.isNotEmpty)
                              Marker(
                                point: _drawnPoints.first,
                                width: 32,
                                height: 32,
                                child: const Icon(
                                  Icons.play_circle_fill,
                                  color: AppColors.success,
                                  size: 32,
                                ),
                              ),
                            if (_drawnPoints.length > 1)
                              Marker(
                                point: _drawnPoints.last,
                                width: 32,
                                height: 32,
                                child: const Icon(
                                  Icons.stop_circle,
                                  color: AppColors.error,
                                  size: 32,
                                ),
                              ),
                            if (_myLocation != null)
                              Marker(
                                point: _myLocation!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.blue,
                                  size: 30,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    // "My location" button overlaid on the map
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'trailMyLocation',
                        onPressed: _isLocating ? null : _useMyLocation,
                        backgroundColor: Theme.of(context).cardColor,
                        foregroundColor: AppColors.primary,
                        tooltip: 'Ma position',
                        child: _isLocating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _drawnPoints.isNotEmpty
                  ? '${_drawnPoints.length} points placés. Cliquez sur la carte pour en ajouter.'
                  : 'Cliquez sur la carte pour tracer l\'itinéraire ou importez un fichier GPX.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            if (_geojson != null && _drawnPoints.isEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'GPX/GeoJSON chargé',
                      style: TextStyle(color: AppColors.success, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAutoMetricsRow() {
    final canCalc = _drawnPoints.length >= 2 && !_isCalculating;
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
              'La distance se met à jour automatiquement à chaque point du '
              'tracé. Le bouton calcule aussi le dénivelé (altitude du '
              'terrain) et la durée estimée. Tous les champs restent '
              'modifiables.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: canCalc ? _calculateMetrics : null,
            icon: _isCalculating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.calculate_outlined, size: 18),
            label: Text(_isCalculating ? 'Calcul...' : 'Calculer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photos du sentier',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Téléversez des photos pour ce sentier (la première est la photo principale)',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ..._imageUrls.asMap().entries.map((entry) {
              final index = entry.key;
              final url = entry.value;
              return _buildImageThumbnail(url, index);
            }),
            _buildUploadButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildPoiSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Points d\'intérêt du sentier',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Cochez les POI à rattacher à ce sentier. Un POI ne peut appartenir '
          'qu\'à un seul sentier.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingPois)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          OutlinedButton.icon(
            onPressed: _allPois.isEmpty ? null : _openPoiPicker,
            icon: const Icon(Icons.place_outlined),
            label: Text(
              _selectedPoiIds.isEmpty
                  ? (_allPois.isEmpty
                      ? 'Aucun POI disponible'
                      : 'Sélectionner des POI')
                  : '${_selectedPoiIds.length} POI sélectionné(s)',
            ),
          ),
      ],
    );
  }

  /// Opens a popup with the checkable list of POIs to attach to this trail.
  Future<void> _openPoiPicker() async {
    final temp = Set<String>.from(_selectedPoiIds);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Points d\'intérêt du sentier'),
              content: SizedBox(
                width: 440,
                child: _allPois.isEmpty
                    ? const Text('Aucun POI disponible.')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _allPois.length,
                        itemBuilder: (c, i) {
                          final poi = _allPois[i];
                          final selected = temp.contains(poi.id);
                          final attachedElsewhere =
                              poi.trailId != null && poi.trailId != _editingId;
                          return CheckboxListTile(
                            dense: true,
                            value: selected,
                            activeColor: AppColors.primary,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) => setLocal(() {
                              if (v == true) {
                                temp.add(poi.id);
                              } else {
                                temp.remove(poi.id);
                              }
                            }),
                            title: Text(poi.name),
                            subtitle: Text(
                              attachedElsewhere && !selected
                                  ? '${poi.typeLabel} · déjà rattaché à un autre sentier'
                                  : poi.typeLabel,
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, temp),
                  child: Text('Valider (${temp.length})'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null) {
      setState(() {
        _selectedPoiIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  Widget _buildImageThumbnail(String url, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.broken_image,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                size: 28,
              ),
            ),
          ),
        ),
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
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: _isUploadingImage
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Téléverser',
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

  // ── Save Button ─────────────────────────────────────
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : () => _saveTrail(asDraft: false),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Enregistrer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // ── Existing Trails Table ───────────────────────────
  Widget _buildExistingTrailsTable(TrailsProvider provider) {
    final isCompact = Responsive.isCompact(context);

    // Client-side search + pagination (5 per page).
    final query = _searchController.text.trim().toLowerCase();
    final filtered = provider.trails.where((t) {
      if (query.isEmpty) return true;
      final name = t.name.toLowerCase();
      final region = (t.region ?? '').toLowerCase();
      return name.contains(query) || region.contains(query);
    }).toList();

    final pageCount = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
    if (_listPage > pageCount - 1) _listPage = pageCount - 1;
    if (_listPage < 0) _listPage = 0;
    final pageItems =
        filtered.skip(_listPage * _pageSize).take(_pageSize).toList();

    final rangeStart = filtered.isEmpty ? 0 : _listPage * _pageSize + 1;
    final rangeEnd = filtered.isEmpty
        ? 0
        : (_listPage * _pageSize + pageItems.length);

    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with search
          if (isCompact) ...[
            const Text(
              'Sentiers existants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() => _listPage = 0),
              decoration: InputDecoration(
                hintText: 'Rechercher des sentiers...',
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ] else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sentiers existants',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() => _listPage = 0),
                    decoration: InputDecoration(
                      hintText: 'Rechercher des sentiers...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          // Filter Bar
          _buildFilterBar(provider),
          const SizedBox(height: 16),
          // Error Banner
          if (provider.error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.error ?? 'Erreur de chargement',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Table Header (desktop/tablet only)
          if (!isCompact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'NOM ET RÉGION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'DISTANCE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'DIFFICULTÉ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'STATUT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      'ACTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Rows
          if (provider.isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (pageItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Aucun sentier trouvé.')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pageItems.length,
              separatorBuilder: (_, __) => SizedBox(height: isCompact ? 8 : 0),
              itemBuilder: (context, index) {
                final trail = pageItems[index];
                return isCompact
                    ? _buildTrailMobileCard(trail)
                    : _buildTrailDesktopRow(trail);
              },
            ),

          // Pagination (client-side)
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Affichage $rangeStart-$rangeEnd sur ${filtered.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: _listPage > 0
                        ? () => setState(() => _listPage--)
                        : null,
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Précédent'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _listPage < pageCount - 1
                        ? () => setState(() => _listPage++)
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 18),
                    label: const Text('Suivant'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(TrailsProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (provider.hasActiveFilters)
            Tooltip(
              message: 'Effacer les filtres',
              child: TextButton.icon(
                onPressed: () => provider.clearAllFilters(),
                icon: const Icon(Icons.clear),
                label: const Text('Réinitialiser filtres'),
              ),
            ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showFilterDialog(provider),
            icon: const Icon(Icons.filter_list),
            label: const Text('Filtrer'),
          ),
          if (provider.filterDifficulty != null) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text('Difficulté: ${provider.filterDifficulty}'),
              onDeleted: () => provider.setDifficultyFilter(null),
            ),
          ],
          if (provider.minDistance != null || provider.maxDistance != null) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text(
                'Distance: ${provider.minDistance ?? 0}-${provider.maxDistance ?? 50}km',
              ),
              onDeleted: () => provider.setDistanceFilter(null, null),
            ),
          ],
          if (provider.maxDuration != null) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text(
                'Durée max: ${_formatDuration(provider.maxDuration!)}',
              ),
              onDeleted: () => provider.setDurationFilter(null),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterDialog(TrailsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => _TrailFilterDialog(provider: provider),
    );
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}min';
    } else if (hours > 0) {
      return '${hours}h';
    }
    return '${mins}min';
  }

  /// Single-row layout used on desktop / wide screens.
  /// The badge is wrapped in `Align` so it no longer stretches to fill
  /// the entire cell height.
  Widget _buildTrailDesktopRow(TrailModel trail) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trail.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  trail.region ?? '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${trail.distance} km',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildDifficultyBadge(trail.difficulty),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              trail.isActive ? 'Actif' : 'Inactif',
              style: TextStyle(
                color: trail.isActive
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _editTrail(trail),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.error,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _deleteTrail(trail),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Vertical card used on mobile (< 700 px).
  Widget _buildTrailMobileCard(TrailModel trail) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trail.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((trail.region ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        trail.region!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildDifficultyBadge(trail.difficulty),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _mobileStatChip(
                icon: Icons.straighten,
                label: '${trail.distance} km',
              ),
              const SizedBox(width: 8),
              _mobileStatChip(
                icon: trail.isActive
                    ? Icons.check_circle_outline
                    : Icons.edit_off_outlined,
                label: trail.isActive ? 'Actif' : 'Inactif',
                color: trail.isActive
                    ? AppColors.success
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _editTrail(trail),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.edit,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _deleteTrail(trail),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileStatChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final c = color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyBadge(TrailDifficulty difficulty) {
    Color bgColor;
    Color textColor;
    String label;

    switch (difficulty) {
      case TrailDifficulty.easy:
        bgColor = AppColors.success;
        textColor = Colors.white;
        label = 'Facile';
        break;
      case TrailDifficulty.moderate:
        bgColor = Colors.orange;
        textColor = Colors.white;
        label = 'Modérée';
        break;
      case TrailDifficulty.difficult:
        bgColor = AppColors.error;
        textColor = Colors.white;
        label = 'Difficile';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TrailFilterDialog extends StatefulWidget {
  final TrailsProvider provider;

  const _TrailFilterDialog({required this.provider});

  @override
  State<_TrailFilterDialog> createState() => _TrailFilterDialogState();
}

class _TrailFilterDialogState extends State<_TrailFilterDialog> {
  late String? _selectedDifficulty;
  late RangeValues _distanceRange;
  late int _selectedDuration;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = widget.provider.filterDifficulty;
    _distanceRange = RangeValues(
      widget.provider.minDistance ?? 0,
      widget.provider.maxDistance ?? 50,
    );
    _selectedDuration = widget.provider.maxDuration ?? 480; // 8 hours default
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtrer les sentiers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Difficulty Filter
              const Text(
                'Difficulté',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _FilterChip(
                    label: 'Tous',
                    selected: _selectedDifficulty == null,
                    onSelected: () =>
                        setState(() => _selectedDifficulty = null),
                  ),
                  _FilterChip(
                    label: 'Facile',
                    selected: _selectedDifficulty == 'easy',
                    onSelected: () =>
                        setState(() => _selectedDifficulty = 'easy'),
                  ),
                  _FilterChip(
                    label: 'Modérée',
                    selected: _selectedDifficulty == 'moderate',
                    onSelected: () =>
                        setState(() => _selectedDifficulty = 'moderate'),
                  ),
                  _FilterChip(
                    label: 'Difficile',
                    selected: _selectedDifficulty == 'difficult',
                    onSelected: () =>
                        setState(() => _selectedDifficulty = 'difficult'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Distance Filter
              const Text(
                'Distance (km)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              RangeSlider(
                values: _distanceRange,
                min: 0,
                max: 50,
                divisions: 50,
                labels: RangeLabels(
                  _distanceRange.start.toStringAsFixed(1),
                  _distanceRange.end.toStringAsFixed(1),
                ),
                onChanged: (values) {
                  setState(() => _distanceRange = values);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_distanceRange.start.toStringAsFixed(1)} km'),
                    Text('${_distanceRange.end.toStringAsFixed(1)} km'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Duration Filter
              const Text(
                'Durée maximale (minutes)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _selectedDuration.toDouble(),
                min: 0,
                max: 600, // 10 hours
                divisions: 60,
                label: _formatDuration(_selectedDuration),
                onChanged: (value) {
                  setState(() => _selectedDuration = value.toInt());
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(_formatDuration(_selectedDuration)),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedDifficulty = null;
                        _distanceRange = const RangeValues(0, 50);
                        _selectedDuration = 480;
                      });
                    },
                    child: const Text('Réinitialiser'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      widget.provider.setDifficultyFilter(_selectedDifficulty);
                      widget.provider.setDistanceFilter(
                        _distanceRange.start,
                        _distanceRange.end,
                      );
                      widget.provider.setDurationFilter(_selectedDuration);
                      Navigator.pop(context);
                    },
                    child: const Text('Appliquer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}min';
    } else if (hours > 0) {
      return '${hours}h';
    }
    return '${mins}min';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
