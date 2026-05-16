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
import '../../core/constants/app_colors.dart';
import '../../core/constants/responsive.dart';
import 'package:http/http.dart' as http;
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

  List<String> _imageUrls = [];
  bool _isUploadingImage = false;

  // GPS recording state
  bool _isRecording = false;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrailsProvider>().loadTrails();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _distanceController.dispose();
    _elevationController.dispose();
    _regionController.dispose();
    _searchController.dispose();
    _mapSearchController.dispose();
    _scrollController.dispose();
    _mapController.dispose();
    _positionStream?.cancel();
    super.dispose();
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
    final ok = await _ensureLocationPermission();
    if (!ok) return;

    setState(() {
      _isRecording = true;
      _drawnPoints = [];
      _geojson = null;
    });

    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      if (mounted) {
        final p = LatLng(initial.latitude, initial.longitude);
        setState(() => _drawnPoints.add(p));
        _mapController.move(p, 17);
      }
    } catch (_) {}

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final p = LatLng(pos.latitude, pos.longitude);
      if (_drawnPoints.isNotEmpty) {
        const d = Distance();
        final m = d.as(LengthUnit.Meter, _drawnPoints.last, p);
        if (m < 1.5) return;
      }
      setState(() => _drawnPoints.add(p));
    });
  }

  Future<void> _stopRecording() async {
    await _positionStream?.cancel();
    _positionStream = null;
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (_drawnPoints.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enregistrement termine : ${_drawnPoints.length} points',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service de localisation desactive'),
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
            content: Text('Permission de localisation refusee'),
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
      if (points.isEmpty) throw Exception('Aucun point trouve dans le GPX');
      setState(() {
        _drawnPoints = points;
        _geojson = null;
      });
      if (points.isNotEmpty) {
        _mapController.move(points.first, 14);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPX importe : ${points.length} points'),
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
          content: Text('Aucun trace a exporter'),
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
          content: Text('GPX exporte (${_drawnPoints.length} points)'),
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
      _regionController.text = trail.region ?? '';
      _difficulty = trail.difficulty;
      _isActive = trail.isActive;
      _geojson = trail.geojson;
      _drawnPoints.clear();

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
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _descriptionController.clear();
      _distanceController.clear();
      _elevationController.clear();
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
                content: Text('Lieu trouvé!'),
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

  Future<void> _saveTrail({bool asDraft = false}) async {
    if (!_formKey.currentState!.validate()) return;
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
      if (_regionController.text.trim().isNotEmpty) {
        data['region'] = _regionController.text.trim();
      }
      data['imageUrls'] = _imageUrls;

      bool success;
      if (_editingId != null) {
        success = await provider.updateTrail(_editingId!, data);
      } else {
        success = await provider.createTrail(data);
      }

      setState(() => _isSaving = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingId != null
                  ? 'Trail updated!'
                  : (asDraft ? 'Draft saved!' : 'Trail published!'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _resetForm();
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to save trail'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Error'),
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
        title: const Text('Confirm Delete'),
        content: Text('Delete "${trail.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<TrailsProvider>().deleteTrail(trail.id);
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrailsProvider>();

    final isCompact = Responsive.isCompact(context);

    final headerTitle = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trail Management',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Create, monitor, and update hiking routes across the ecosystem.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );

    final createButton = ElevatedButton.icon(
      onPressed: _resetForm,
      icon: const Icon(Icons.add),
      label: const Text('Create New Trail'),
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

          // Form + Sidebar
          if (isCompact)
            Column(
              key: _formSectionKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTrailDetailsForm(),
                const SizedBox(height: 24),
                _buildProTipCard(),
                const SizedBox(height: 24),
                _buildPublishingCard(),
              ],
            )
          else
            Row(
              key: _formSectionKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildTrailDetailsForm()),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildProTipCard(),
                      const SizedBox(height: 24),
                      _buildPublishingCard(),
                    ],
                  ),
                ),
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
    String avgDiff = 'Moderate';
    if (easyCount >= modCount && easyCount >= diffCount) avgDiff = 'Easy';
    if (diffCount >= modCount && diffCount >= easyCount) avgDiff = 'Hard';

    final cards = [
      _statCard(
        'Total Trails',
        provider.total.toString(),
        Icons.terrain,
        AppColors.primary,
      ),
      _statCard('Active Hikers', '1,284', Icons.people, Colors.blue),
      _statCard(
        'Total Distance',
        '${totalDistance.toStringAsFixed(0)} km',
        Icons.straighten,
        Colors.teal,
      ),
      _statCard(
        'Avg. Difficulty',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editingId != null ? 'Edit Trail' : 'Trail Details',
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
                      labelText: 'Trail Name',
                      hintText: 'e.g. Pine Ridge Loop',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<TrailDifficulty>(
                    value: _difficulty,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Difficulty Level',
                      border: OutlineInputBorder(),
                    ),
                    items: TrailDifficulty.values.map((d) {
                      String label = d == TrailDifficulty.easy
                          ? 'Easy'
                          : d == TrailDifficulty.moderate
                          ? 'Moderate'
                          : 'Hard';
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
                hintText: 'Describe the terrain, views and safety tips...',
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
                            v?.isEmpty == true ? 'Required' : null,
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
                        'Elevation Gain (m)',
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
            const SizedBox(height: 24),

            // Route Path
            const Text(
              'Route Path',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isRecording ? AppColors.error : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  icon: Icon(_isRecording
                      ? Icons.stop_circle_outlined
                      : Icons.fiber_manual_record),
                  label: Text(_isRecording
                      ? 'Arreter l\'enregistrement'
                      : 'Demarrer enregistrement GPS'),
                ),
                OutlinedButton.icon(
                  onPressed: _isRecording ? null : _importGpx,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Importer GPX'),
                ),
                OutlinedButton.icon(
                  onPressed: _drawnPoints.length >= 2 && !_isRecording
                      ? _exportGpx
                      : null,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Exporter GPX'),
                ),
                if (_drawnPoints.isNotEmpty && !_isRecording) ...[
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _drawnPoints.removeLast()),
                    icon: const Icon(
                      Icons.undo,
                      size: 18,
                      color: Colors.orange,
                    ),
                    label: const Text(
                      'Undo',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _drawnPoints.clear()),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.error,
                    ),
                    label: const Text(
                      'Clear Path',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
                if (_isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.gps_fixed,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Enregistrement... ${_drawnPoints.length} pts',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textHint,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
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
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: 14.0,
                    onTap: (tapPosition, point) {
                      setState(() => _drawnPoints.add(point));
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _drawnPoints.isNotEmpty
                  ? '${_drawnPoints.length} points plotted. Click map to add more.'
                  : 'Click on the map to draw the route or upload a GPX file.',
              style: const TextStyle(
                color: AppColors.textSecondary,
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
                      'GPX/GeoJSON loaded',
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

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trail Photos',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Upload photos for this trail (first photo is the main one)',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.broken_image,
                color: AppColors.textHint,
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
                'Main',
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
          color: Colors.grey[50],
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
                    'Upload',
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

  // ── Pro Tip Card ─────────────────────────────────────
  Widget _buildProTipCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: AppColors.success, size: 28),
          const SizedBox(height: 12),
          const Text(
            'Pro Tip',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Include high-resolution photos of trail markers to help hikers stay on track. GPS coordinates for water sources are highly recommended.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Publishing Status Card ──────────────────────────
  Widget _buildPublishingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Publishing Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Switch(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeColor: AppColors.success,
              ),
              const SizedBox(width: 8),
              Text(
                _isActive ? 'Visible to Public' : 'Hidden (Draft)',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => _saveTrail(asDraft: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Save Draft'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _saveTrail(asDraft: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
                  : Text(_editingId != null ? 'Update Trail' : 'Publish Trail'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Existing Trails Table ───────────────────────────
  Widget _buildExistingTrailsTable(TrailsProvider provider) {
    final isCompact = Responsive.isCompact(context);
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with search
          if (isCompact) ...[
            const Text(
              'Existing Trails',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search trails...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                filled: true,
                fillColor: Colors.grey[50],
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
                  'Existing Trails',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search trails...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textHint,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
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
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'NAME & REGION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
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
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'DIFFICULTY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
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
                        color: AppColors.textSecondary,
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
          else if (provider.trails.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No trails found.')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.trails.length,
              separatorBuilder: (_, __) => SizedBox(height: isCompact ? 8 : 0),
              itemBuilder: (context, index) {
                final trail = provider.trails[index];
                return isCompact
                    ? _buildTrailMobileCard(trail)
                    : _buildTrailDesktopRow(trail);
              },
            ),

          // Pagination
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing 1-${provider.trails.length} of ${provider.total} trails',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: provider.currentPage > 1
                        ? () => provider.loadTrails(
                            page: provider.currentPage - 1,
                          )
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: provider.currentPage < provider.totalPages
                        ? () => provider.loadTrails(
                            page: provider.currentPage + 1,
                          )
                        : null,
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
                  style: const TextStyle(
                    color: AppColors.textSecondary,
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
              style: const TextStyle(color: AppColors.textPrimary),
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
              trail.isActive ? 'Published' : 'Draft',
              style: TextStyle(
                color: trail.isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.edit,
                    size: 18,
                    color: AppColors.textSecondary,
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
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
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
                        style: const TextStyle(
                          color: AppColors.textSecondary,
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
                label: trail.isActive ? 'Published' : 'Draft',
                color: trail.isActive
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
              const Spacer(),
              InkWell(
                onTap: () => _editTrail(trail),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.edit,
                    size: 20,
                    color: AppColors.textSecondary,
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
    final c = color ?? AppColors.textSecondary;
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
        label = 'Easy';
        break;
      case TrailDifficulty.moderate:
        bgColor = Colors.orange;
        textColor = Colors.white;
        label = 'Moderate';
        break;
      case TrailDifficulty.difficult:
        bgColor = AppColors.error;
        textColor = Colors.white;
        label = 'Hard';
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
