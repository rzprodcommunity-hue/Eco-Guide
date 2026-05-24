import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../core/providers/pois_provider.dart';
import '../../core/models/poi_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/responsive.dart';
import '../../core/services/supabase_storage_service.dart';

class PoisScreen extends StatefulWidget {
  const PoisScreen({super.key});

  @override
  State<PoisScreen> createState() => _PoisScreenState();
}

class _PoisScreenState extends State<PoisScreen> {
  final _searchController = TextEditingController();
  String? _selectedFilter;

  // Form State
  PoiModel? _editingPoi;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  PoiType _selectedType = PoiType.flora;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isUploading = false;
  LatLng _selectedLocation = const LatLng(
    45.4215,
    -75.6972,
  ); // Default to Ottawa
  String? _mediaUrl;
  Uint8List? _pickedImageBytes;

  // Map controls (search + my location)
  final MapController _mapController = MapController();
  final TextEditingController _mapSearchController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  bool _isSearchingMap = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _latitudeController.text = _selectedLocation.latitude.toStringAsFixed(6);
    _longitudeController.text = _selectedLocation.longitude.toStringAsFixed(6);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoisProvider>().loadPois();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _mapSearchController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _editingPoi = null;
      _nameController.clear();
      _descriptionController.clear();
      _selectedType = PoiType.flora;
      _isActive = true;
      _mediaUrl = null;
      _pickedImageBytes = null;
      _formKey.currentState?.reset();
    });
  }

  void _editPoi(PoiModel poi) {
    setState(() {
      _editingPoi = poi;
      _selectedLocation = LatLng(poi.latitude, poi.longitude);
      _latitudeController.text = poi.latitude.toString();
      _longitudeController.text = poi.longitude.toString();
      _nameController.text = poi.name;
      _descriptionController.text = poi.description;
      _selectedType = poi.type;
      _isActive = poi.isActive;
      _mediaUrl = poi.mediaUrl;
      _pickedImageBytes = null;
    });
  }

  Future<void> _deletePoi(PoiModel poi) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            const Text('Delete Marker'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${poi.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final success = await context.read<PoisProvider>().deletePoi(poi.id);
      if (success && mounted) {
        if (_editingPoi?.id == poi.id) _resetForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marker deleted'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;
    setState(() {
      _pickedImageBytes = file.bytes;
      _isUploading = true;
    });

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
        _mediaUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _savePoi() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final provider = context.read<PoisProvider>();
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : 'No description',
        'type': _selectedType.name,
        'latitude': _location.latitude,
        'longitude': _location.longitude,
        'isActive': _isActive,
      };

      if (_mediaUrl != null && _mediaUrl!.isNotEmpty) {
        data['mediaUrl'] = _mediaUrl;
      }

      bool success;
      if (_editingPoi != null) {
        success = await provider.updatePoi(_editingPoi!.id, data);
      } else {
        success = await provider.createPoi(data);
      }

      setState(() => _isSaving = false);

      if (success && mounted) {
        _resetForm();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingPoi != null
                  ? 'POI updated successfully!'
                  : 'POI created successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        provider.loadPois(type: _selectedFilter);
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to save'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  LatLng get _location => _selectedLocation;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PoisProvider>();

    final isCompact = Responsive.isCompact(context);

    final headerTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Points of Interest Management',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Manage markers, educational content, and geographic assets',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );

    final addButton = ElevatedButton.icon(
      onPressed: _resetForm,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add New POI'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );

    return SingleChildScrollView(
      padding: Responsive.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerTitle,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: addButton),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [headerTitle, addButton],
            ),
          const SizedBox(height: 24),

          // ── Search & Category Filters ──
          _buildSearchAndFilters(provider),
          const SizedBox(height: 24),

          // ── Main Content Area ──
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMapCard(),
                const SizedBox(height: 24),
                _buildPoiDetailsForm(),
                const SizedBox(height: 24),
                _buildExistingMarkers(provider),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 13,
                  child: Column(
                    children: [
                      _buildMapCard(),
                      const SizedBox(height: 24),
                      _buildPoiDetailsForm(),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(flex: 8, child: _buildExistingMarkers(provider)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(PoisProvider provider) {
    final categories = [
      {'label': 'All', 'value': null, 'icon': Icons.apps},
      {'label': 'Fauna', 'value': 'fauna', 'icon': Icons.pets},
      {'label': 'Flora', 'value': 'flora', 'icon': Icons.eco},
      {'label': 'Heritage', 'value': 'historical', 'icon': Icons.account_balance},
      {'label': 'Viewpoint', 'value': 'viewpoint', 'icon': Icons.visibility},
      {'label': 'Water', 'value': 'water', 'icon': Icons.waves},
      {'label': 'Danger', 'value': 'danger', 'icon': Icons.report_problem},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search markers by name or category...',
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AppColors.textHint, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textHint),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = _selectedFilter == cat['value'];
              final icon = cat['icon'] as IconData;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      setState(() => _selectedFilter = cat['value'] as String?);
                      provider.loadPois(type: _selectedFilter);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.divider.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 14,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['label'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Search a place via OpenStreetMap (Nominatim) ───────────────────────
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
          setState(() {
            _selectedLocation = newCenter;
            _latitudeController.text = lat.toStringAsFixed(6);
            _longitudeController.text = lon.toStringAsFixed(6);
          });
          _mapController.move(newCenter, 14.0);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lieu trouvé!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lieu introuvable'),
              backgroundColor: AppColors.error,
            ),
          );
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
      if (mounted) setState(() => _isSearchingMap = false);
    }
  }

  // ── Show my current location on the map ────────────────────────────────
  Future<void> _useMyLocation() async {
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
      final p = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _selectedLocation = p;
        _latitudeController.text = p.latitude.toStringAsFixed(6);
        _longitudeController.text = p.longitude.toStringAsFixed(6);
      });
      _mapController.move(p, 15);
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

  // ── Apply manually-typed latitude/longitude to the map ─────────────────
  void _syncLocationFromFields({bool moveMap = false}) {
    final lat = double.tryParse(_latitudeController.text.trim());
    final lng = double.tryParse(_longitudeController.text.trim());
    if (lat == null || lng == null) return;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return;
    final p = LatLng(lat, lng);
    setState(() => _selectedLocation = p);
    if (moveMap) _mapController.move(p, 15);
  }

  Widget _buildMapCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Search bar (OpenStreetMap / Nominatim)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
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
          ),
          SizedBox(
            height: 320,
            child: ClipRRect(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLocation,
                      initialZoom: 13.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedLocation = point;
                          _latitudeController.text =
                              point.latitude.toStringAsFixed(6);
                          _longitudeController.text =
                              point.longitude.toStringAsFixed(6);
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                        userAgentPackageName: 'com.ecoguide.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: AppColors.error,
                              size: 40,
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
                      heroTag: 'poiMyLocation',
                      onPressed: _isLocating ? null : _useMyLocation,
                      backgroundColor: Colors.white,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.divider.withValues(alpha: 0.3)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Latitude',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (_) => _syncLocationFromFields(),
                        onSubmitted: (_) =>
                            _syncLocationFromFields(moveMap: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _longitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (_) => _syncLocationFromFields(),
                        onSubmitted: (_) =>
                            _syncLocationFromFields(moveMap: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Icon(Icons.touch_app, size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cliquez sur la carte, cherchez un lieu, ou saisissez les coordonnées',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
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

  Widget _buildPoiDetailsForm() {
    final isCompact = Responsive.isCompact(context);
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'POI Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Active',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        activeColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _poiNameField(),
                      const SizedBox(height: 16),
                      _poiCategoryField(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _poiNameField()),
                      const SizedBox(width: 20),
                      Expanded(flex: 1, child: _poiCategoryField()),
                    ],
                  ),
            const SizedBox(height: 20),
            const Text(
              'Description',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Educational details about this point...',
                hintStyle: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gallery Images',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : _savePoi,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(_editingPoi != null ? 'Update POI' : 'Save POI'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: _isUploading ? null : _pickAndUploadImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider, width: 1.5),
                    ),
                    child: _isUploading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.camera_alt,
                                color: AppColors.textHint,
                                size: 24,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Upload',
                                style: TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                if (_pickedImageBytes != null) ...[
                  const SizedBox(width: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _pickedImageBytes!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ] else if (_mediaUrl != null && _mediaUrl!.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _mediaUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: () => setState(() => _mediaUrl = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _poiNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'POI Name',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'e.g. Ancient Oak Grove',
            hintStyle: const TextStyle(
              color: AppColors.textHint,
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _poiCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<PoiType>(
          value: _selectedType,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: PoiType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(
                    _getTypeLabel(type),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedType = v);
          },
        ),
      ],
    );
  }

  Widget _buildExistingMarkers(PoisProvider provider) {
    final activeCount = provider.pois.where((p) => p.isActive).length;
    final filtered = _searchController.text.isEmpty
        ? provider.pois
        : provider.pois
            .where((p) => p.name.toLowerCase().contains(_searchController.text.toLowerCase()))
            .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with counters (wraps gracefully on narrow widths)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Existing Markers',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${provider.pois.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildStatChip(
                      label: '$activeCount active',
                      color: AppColors.success,
                    ),
                    _buildStatChip(
                      label: '${provider.pois.length - activeCount} draft',
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.4)),
          // List
          SizedBox(
            height: 620,
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.place_outlined,
                            size: 48, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        const Text(
                          'No markers found',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Try adjusting your search or filters',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final poi = filtered[index];
                      final isSelected = _editingPoi?.id == poi.id;
                      final typeColor = _getTypeColor(poi.type);
                      final typeIcon = _getTypeIcon(poi.type);
                      return Material(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.04)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => _editPoi(poi),
                          child: Container(
                            decoration: BoxDecoration(
                              border: isSelected
                                  ? Border(
                                      left: BorderSide(
                                        color: AppColors.primary,
                                        width: 3,
                                      ),
                                    )
                                  : null,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: poi.mediaUrl != null
                                      ? Image.network(
                                          poi.mediaUrl!,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _buildPoiPlaceholder(poi.type),
                                        )
                                      : _buildPoiPlaceholder(poi.type),
                                ),
                                const SizedBox(width: 14),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        poi.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: Color(0xFF1E293B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 5),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          // Type badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: typeColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(typeIcon,
                                                    size: 11,
                                                    color: typeColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _getTypeLabel(poi.type),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: typeColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Status badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: poi.isActive
                                                  ? AppColors.success.withValues(alpha: 0.1)
                                                  : Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: poi.isActive
                                                    ? AppColors.success.withValues(alpha: 0.25)
                                                    : Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: poi.isActive
                                                        ? AppColors.success
                                                        : AppColors.textHint,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  poi.isActive ? 'Active' : 'Draft',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: poi.isActive
                                                        ? AppColors.success
                                                        : AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Actions
                                Row(
                                  children: [
                                    _buildActionButton(
                                      icon: Icons.edit_outlined,
                                      color: AppColors.primary,
                                      onTap: () => _editPoi(poi),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildActionButton(
                                      icon: Icons.delete_outline,
                                      color: AppColors.error,
                                      onTap: () => _deletePoi(poi),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.4)),
          // Pagination
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${filtered.length} of ${provider.pois.length} markers',
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
                Row(
                  children: [
                    _buildPageButton(
                      icon: Icons.chevron_left,
                      enabled: provider.currentPage > 1,
                      onTap: () => provider.loadPois(
                        page: provider.currentPage - 1,
                        type: _selectedFilter,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Page ${provider.currentPage} / ${provider.totalPages == 0 ? 1 : provider.totalPages}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _buildPageButton(
                      icon: Icons.chevron_right,
                      enabled: provider.currentPage < provider.totalPages,
                      onTap: () => provider.loadPois(
                        page: provider.currentPage + 1,
                        type: _selectedFilter,
                      ),
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

  Widget _buildStatChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _buildPageButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: enabled ? Colors.white : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.textSecondary : AppColors.textHint,
          ),
        ),
      ),
    );
  }

  Widget _buildPoiPlaceholder(PoiType type) {
    final color = _getTypeColor(type);
    final icon = _getTypeIcon(type);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }

  Color _getTypeColor(PoiType type) {
    switch (type) {
      case PoiType.fauna:
        return const Color(0xFFE65100);
      case PoiType.flora:
        return const Color(0xFF2E7D32);
      case PoiType.historical:
        return const Color(0xFF1565C0);
      case PoiType.viewpoint:
        return const Color(0xFF00838F);
      case PoiType.water:
        return const Color(0xFF0277BD);
      case PoiType.camping:
        return const Color(0xFF6D4C41);
      case PoiType.danger:
        return const Color(0xFFD32F2F);
      case PoiType.rest_area:
        return const Color(0xFF6A1B9A);
      case PoiType.information:
        return const Color(0xFF455A64);
    }
  }

  IconData _getTypeIcon(PoiType type) {
    switch (type) {
      case PoiType.fauna:
        return Icons.pets;
      case PoiType.flora:
        return Icons.eco;
      case PoiType.historical:
        return Icons.account_balance;
      case PoiType.viewpoint:
        return Icons.landscape;
      case PoiType.water:
        return Icons.waves;
      case PoiType.camping:
        return Icons.cabin;
      case PoiType.danger:
        return Icons.report_problem;
      case PoiType.rest_area:
        return Icons.weekend;
      case PoiType.information:
        return Icons.info_outline;
    }
  }

  String _getTypeLabel(PoiType type) {
    switch (type) {
      case PoiType.historical:
        return 'Heritage';
      case PoiType.flora:
        return 'Flora';
      case PoiType.fauna:
        return 'Fauna';
      case PoiType.viewpoint:
        return 'Viewpoint';
      case PoiType.water:
        return 'Water';
      case PoiType.camping:
        return 'Camping';
      case PoiType.danger:
        return 'Danger';
      case PoiType.rest_area:
        return 'Rest Area';
      case PoiType.information:
        return 'Information';
    }
  }
}
