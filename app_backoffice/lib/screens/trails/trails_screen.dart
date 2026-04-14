import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/providers/trails_provider.dart';
import '../../core/models/trail_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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
  LatLng _mapCenter = const LatLng(31.6295, -7.9811);
  final _scrollController = ScrollController();
  final _formSectionKey = GlobalKey();
  
  List<String> _imageUrls = [];
  bool _isUploadingImage = false;

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
    _scrollController.dispose();
    super.dispose();
  }

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
      if (trail.startLatitude != null && trail.startLongitude != null) {
        _mapCenter = LatLng(trail.startLatitude!, trail.startLongitude!);
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
      _imageUrls = [];
      _mapCenter = const LatLng(31.6295, -7.9811);
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

  Future<void> _pickGeoJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'geojson', 'gpx'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      try {
        final content = utf8.decode(result.files.single.bytes!);
        final json = jsonDecode(content);
        setState(() => _geojson = json);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPX/GeoJSON imported successfully'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid file format'), backgroundColor: AppColors.error),
          );
        }
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
        'startLatitude': _mapCenter.latitude,
        'startLongitude': _mapCenter.longitude,
        'isActive': asDraft ? false : _isActive,
      };

      // Only add optional fields if they have values
      if (_elevationController.text.isNotEmpty) {
        data['elevationGain'] = int.tryParse(_elevationController.text);
      }
      if (_regionController.text.trim().isNotEmpty) {
        data['region'] = _regionController.text.trim();
      }
      if (_geojson != null) {
        data['geojson'] = _geojson;
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
            content: Text(_editingId != null ? 'Trail updated!' : (asDraft ? 'Draft saved!' : 'Trail published!')),
            backgroundColor: AppColors.success,
          ),
        );
        _resetForm();
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Failed to save trail'), backgroundColor: AppColors.error),
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
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
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
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
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
      final uri = Uri.parse(ApiConstants.mediaUploadImage);
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer ${ApiService.token}';
      String mimeType = 'jpeg';
      String ext = file.name.split('.').last.toLowerCase();
      if (ext == 'png') mimeType = 'png';
      else if (ext == 'gif') mimeType = 'gif';
      else if (ext == 'webp') mimeType = 'webp';

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
        contentType: MediaType('image', mimeType),
      ));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final url = body['url'] as String;
        setState(() {
          _imageUrls.add(url);
          _isUploadingImage = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image uploadée avec succès!'), backgroundColor: AppColors.success),
          );
        }
      } else {
        setState(() => _isUploadingImage = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload échoué: ${response.body}'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload: $e'), backgroundColor: AppColors.error),
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

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trail Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('Create, monitor, and update hiking routes across the ecosystem.', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.add),
                label: const Text('Create New Trail'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats Cards
          _buildStatsRow(provider),
          const SizedBox(height: 24),

          // Form + Sidebar
          Row(
            key: _formSectionKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Trail Details Form
              Expanded(
                flex: 3,
                child: _buildTrailDetailsForm(),
              ),
              const SizedBox(width: 24),
              // Right: Pro Tip + Publishing Status
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

    return Row(
      children: [
        Expanded(child: _statCard('Total Trails', provider.total.toString(), Icons.terrain, AppColors.primary)),
        const SizedBox(width: 16),
        Expanded(child: _statCard('Active Hikers', '1,284', Icons.people, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _statCard('Total Distance', '${totalDistance.toStringAsFixed(0)} km', Icons.straighten, Colors.teal)),
        const SizedBox(width: 16),
        Expanded(child: _statCard('Avg. Difficulty', avgDiff, Icons.signal_cellular_alt, Colors.orange)),
      ],
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
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                      String label = d == TrailDifficulty.easy ? 'Easy' : d == TrailDifficulty.moderate ? 'Moderate' : 'Hard';
                      return DropdownMenuItem(value: d, child: Text(label));
                    }).toList(),
                    onChanged: (v) => setState(() => _difficulty = v ?? TrailDifficulty.moderate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      const Text('Distance (km)', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _distanceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0.0'),
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Elevation Gain (m)', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _elevationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Route Path + Upload GPX
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Route Path', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                TextButton.icon(
                  onPressed: _pickGeoJson,
                  icon: const Icon(Icons.upload_file, size: 18, color: AppColors.success),
                  label: const Text('Upload GPX', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: 10.0,
                    onTap: (tapPosition, point) {
                      setState(() => _mapCenter = point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.ecoguide.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _mapCenter,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_pin, color: AppColors.error, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_geojson != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 16),
                    SizedBox(width: 6),
                    Text('GPX/GeoJSON loaded', style: TextStyle(color: AppColors.success, fontSize: 13)),
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
        const Text('Trail Photos', style: TextStyle(fontWeight: FontWeight.w600)),
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
              child: const Icon(Icons.broken_image, color: AppColors.textHint, size: 28),
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
              decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
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
              decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(8)),
              child: const Text('Main', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
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
          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
        ),
        child: _isUploadingImage
            ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)))
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 28),
                  SizedBox(height: 6),
                  Text('Upload', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
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
          const Text('Pro Tip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Include high-resolution photos of trail markers to help hikers stay on track. GPS coordinates for water sources are highly recommended.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
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
          const Text('Publishing Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Switch(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeColor: AppColors.success,
              ),
              const SizedBox(width: 8),
              Text(_isActive ? 'Visible to Public' : 'Hidden (Draft)', style: const TextStyle(fontWeight: FontWeight.w500)),
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
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_editingId != null ? 'Update Trail' : 'Publish Trail'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Existing Trails Table ───────────────────────────
  Widget _buildExistingTrailsTable(TrailsProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with search
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Existing Trails', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search trails...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('NAME & REGION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('DISTANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('DIFFICULTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5))),
                SizedBox(width: 80, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5))),
              ],
            ),
          ),

          // Rows
          if (provider.isLoading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (provider.trails.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No trails found.')))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.trails.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final trail = provider.trails[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Name & Region
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trail.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(trail.region ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      // Distance
                      Expanded(
                        flex: 2,
                        child: Text('${trail.distance} km', style: const TextStyle(color: AppColors.textPrimary)),
                      ),
                      // Difficulty
                      Expanded(
                        flex: 2,
                        child: _buildDifficultyBadge(trail.difficulty),
                      ),
                      // Status
                      Expanded(
                        flex: 2,
                        child: Text(
                          trail.isActive ? 'Published' : 'Draft',
                          style: TextStyle(
                            color: trail.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Actions
                      SizedBox(
                        width: 80,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _editTrail(trail),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
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
              },
            ),

          // Pagination
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing 1-${provider.trails.length} of ${provider.total} trails',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: provider.currentPage > 1 ? () => provider.loadTrails(page: provider.currentPage - 1) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: provider.currentPage < provider.totalPages ? () => provider.loadTrails(page: provider.currentPage + 1) : null,
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
              label: Text('Distance: ${provider.minDistance ?? 0}-${provider.maxDistance ?? 50}km'),
              onDeleted: () => provider.setDistanceFilter(null, null),
            ),
          ],
          if (provider.maxDuration != null) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text('Durée max: ${_formatDuration(provider.maxDuration!)}'),
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
      child: Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
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
              const Text('Difficulté', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _FilterChip(
                    label: 'Tous',
                    selected: _selectedDifficulty == null,
                    onSelected: () => setState(() => _selectedDifficulty = null),
                  ),
                  _FilterChip(
                    label: 'Facile',
                    selected: _selectedDifficulty == 'easy',
                    onSelected: () => setState(() => _selectedDifficulty = 'easy'),
                  ),
                  _FilterChip(
                    label: 'Modérée',
                    selected: _selectedDifficulty == 'moderate',
                    onSelected: () => setState(() => _selectedDifficulty = 'moderate'),
                  ),
                  _FilterChip(
                    label: 'Difficile',
                    selected: _selectedDifficulty == 'difficult',
                    onSelected: () => setState(() => _selectedDifficulty = 'difficult'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Distance Filter
              const Text('Distance (km)', style: TextStyle(fontWeight: FontWeight.bold)),
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
              const Text('Durée maximale (minutes)', style: TextStyle(fontWeight: FontWeight.bold)),
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
