import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/providers/pois_provider.dart';
import '../../core/models/poi_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';

class PoisScreen extends StatefulWidget {
  const PoisScreen({super.key});

  @override
  State<PoisScreen> createState() => _PoisScreenState();
}

class _PoisScreenState extends State<PoisScreen> {
  final _searchController = TextEditingController();
  String? _selectedFilter;
  LatLng _selectedLocation = const LatLng(31.6295, -7.9811);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoisProvider>().loadPois();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showPoiDialog({PoiModel? poi}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PoiFormDialog(
        poi: poi,
        initialLocation: poi != null ? LatLng(poi.latitude, poi.longitude) : _selectedLocation,
        onSaved: () {
          context.read<PoisProvider>().loadPois(type: _selectedFilter);
        },
      ),
    );
  }

  void _editPoi(PoiModel poi) {
    setState(() {
      _selectedLocation = LatLng(poi.latitude, poi.longitude);
    });
    _showPoiDialog(poi: poi);
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
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Marker'),
          ],
        ),
        content: Text('Are you sure you want to delete "${poi.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final success = await context.read<PoisProvider>().deletePoi(poi.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marker deleted'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PoisProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Points of Interest Management',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 6),
                  Text('Manage markers, educational content, and geographic assets.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showPoiDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New POI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Search + Category Filters ──
          _buildSearchAndFilters(provider),
          const SizedBox(height: 24),

          // ── Map + Existing Markers ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildMapSection(provider)),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _buildExistingMarkers(provider)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Search + Category Filters ──
  Widget _buildSearchAndFilters(PoisProvider provider) {
    final categories = [
      {'label': 'All', 'value': null},
      {'label': 'Fauna', 'value': 'fauna'},
      {'label': 'Flora', 'value': 'flora'},
      {'label': 'Heritage', 'value': 'historical'},
      {'label': 'Viewpoint', 'value': 'viewpoint'},
      {'label': 'Water', 'value': 'water'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search markers by name or category...',
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.textHint, size: 20),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(width: 20),
          ...categories.map((cat) {
            final isSelected = _selectedFilter == cat['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: isSelected ? AppColors.success : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() => _selectedFilter = cat['value'] as String?);
                    provider.loadPois(type: _selectedFilter);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.success : AppColors.divider),
                    ),
                    child: Text(
                      cat['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Map Section with all markers ──
  Widget _buildMapSection(PoisProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 400,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _selectedLocation,
                  initialZoom: 8.0,
                  onTap: (tapPosition, point) {
                    setState(() => _selectedLocation = point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ecoguide.app',
                  ),
                  MarkerLayer(
                    markers: [
                      // Show all POI markers on the map
                      ...provider.pois.map((poi) => Marker(
                        point: LatLng(poi.latitude, poi.longitude),
                        width: 36,
                        height: 36,
                        child: Tooltip(
                          message: poi.name,
                          child: Icon(
                            _getTypeIcon(poi.type),
                            color: _getTypeColor(poi.type),
                            size: 32,
                          ),
                        ),
                      )),
                      // Selected location marker
                      Marker(
                        point: _selectedLocation,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider.withOpacity(0.3))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.my_location, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Location: ${_selectedLocation.latitude.toStringAsFixed(4)}° N, ${_selectedLocation.longitude.toStringAsFixed(4)}° W',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, size: 14, color: AppColors.success),
                      SizedBox(width: 4),
                      Text('Click map to set marker', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Existing Markers List (max 4 visible, scrollable) ──
  Widget _buildExistingMarkers(PoisProvider provider) {
    return Container(
      height: 478,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Existing Markers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${provider.total} total',
                  style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Scrollable list area
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.pois.isEmpty
                    ? const Center(child: Text('No markers found.', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.separated(
                        itemCount: provider.pois.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider.withOpacity(0.4)),
                        itemBuilder: (context, index) {
                          final poi = provider.pois[index];
                          return _buildMarkerItem(poi);
                        },
                      ),
          ),
          const SizedBox(height: 8),
          // Pagination
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider.withOpacity(0.4))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: provider.currentPage > 1 ? () => provider.loadPois(page: provider.currentPage - 1, type: _selectedFilter) : null,
                ),
                Text('Page ${provider.currentPage} of ${provider.totalPages}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: provider.currentPage < provider.totalPages ? () => provider.loadPois(page: provider.currentPage + 1, type: _selectedFilter) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkerItem(PoiModel poi) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: poi.mediaUrl != null
                ? Image.network(poi.mediaUrl!, width: 52, height: 52, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPoiPlaceholder(poi.type))
                : _buildPoiPlaceholder(poi.type),
          ),
          const SizedBox(width: 12),
          // Name & Type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(poi.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1),
                const SizedBox(height: 3),
                Text(_getTypeLabel(poi.type), style: TextStyle(color: _getTypeColor(poi.type), fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: poi.isActive ? AppColors.success : Colors.orange,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              poi.isActive ? 'Ac.' : 'Dr.',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          // Actions
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Edit',
            onPressed: () => _editPoi(poi),
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Delete',
            onPressed: () => _deletePoi(poi),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──
  Widget _buildPoiPlaceholder(PoiType type) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_getTypeColor(type).withOpacity(0.15), _getTypeColor(type).withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(_getTypeIcon(type), color: _getTypeColor(type), size: 24),
    );
  }

  IconData _getTypeIcon(PoiType type) {
    switch (type) {
      case PoiType.viewpoint: return Icons.landscape;
      case PoiType.flora: return Icons.local_florist;
      case PoiType.fauna: return Icons.pets;
      case PoiType.historical: return Icons.account_balance;
      case PoiType.water: return Icons.water_drop;
      case PoiType.camping: return Icons.cabin;
      case PoiType.danger: return Icons.warning;
      case PoiType.rest_area: return Icons.weekend;
      case PoiType.information: return Icons.info;
    }
  }

  Color _getTypeColor(PoiType type) {
    switch (type) {
      case PoiType.viewpoint: return Colors.blue;
      case PoiType.flora: return Colors.green;
      case PoiType.fauna: return Colors.orange;
      case PoiType.historical: return Colors.purple;
      case PoiType.water: return Colors.cyan.shade700;
      case PoiType.camping: return Colors.brown;
      case PoiType.danger: return Colors.red;
      case PoiType.rest_area: return Colors.teal;
      case PoiType.information: return Colors.indigo;
    }
  }

  String _getTypeLabel(PoiType type) {
    switch (type) {
      case PoiType.viewpoint: return 'Viewpoint';
      case PoiType.flora: return 'Flora';
      case PoiType.fauna: return 'Fauna';
      case PoiType.historical: return 'Heritage';
      case PoiType.water: return 'Water';
      case PoiType.camping: return 'Camping';
      case PoiType.danger: return 'Danger';
      case PoiType.rest_area: return 'Rest Area';
      case PoiType.information: return 'Information';
    }
  }
}

// ══════════════════════════════════════════════════════
//  POI Form Dialog (Popup) with Image Upload
// ══════════════════════════════════════════════════════
class _PoiFormDialog extends StatefulWidget {
  final PoiModel? poi;
  final LatLng initialLocation;
  final VoidCallback onSaved;

  const _PoiFormDialog({this.poi, required this.initialLocation, required this.onSaved});

  @override
  State<_PoiFormDialog> createState() => _PoiFormDialogState();
}

class _PoiFormDialogState extends State<_PoiFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  PoiType _selectedType = PoiType.flora;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isUploading = false;
  late LatLng _location;

  String? _mediaUrl;
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;

  bool get isEditing => widget.poi != null;

  @override
  void initState() {
    super.initState();
    _location = widget.initialLocation;
    if (widget.poi != null) {
      _nameController.text = widget.poi!.name;
      _descriptionController.text = widget.poi!.description;
      _selectedType = widget.poi!.type;
      _isActive = widget.poi!.isActive;
      _mediaUrl = widget.poi!.mediaUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
      _pickedImageName = file.name;
      _isUploading = true;
    });

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
        setState(() {
          _mediaUrl = body['url'];
          _isUploading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image uploaded!'), backgroundColor: AppColors.success),
          );
        }
      } else {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: ${response.body}'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _save() async {
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
      if (isEditing) {
        success = await provider.updatePoi(widget.poi!.id, data);
      } else {
        success = await provider.createPoi(data);
      }

      setState(() => _isSaving = false);

      if (success && mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'POI updated successfully!' : 'POI created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Failed to save'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 24),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.3))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_location_alt : Icons.add_location_alt,
                      color: AppColors.success,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Point of Interest' : 'Create New Point of Interest',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEditing ? 'Update the marker details below' : 'Fill in the details to add a new marker',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Dialog Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Image Upload Section ──
                      const Text('Photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      const Text('Upload a photo for this point of interest',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Upload button
                          GestureDetector(
                            onTap: _isUploading ? null : _pickAndUploadImage,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.divider,
                                  style: BorderStyle.solid,
                                  width: 2,
                                ),
                              ),
                              child: _isUploading
                                  ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt_outlined, color: AppColors.success, size: 28),
                                        const SizedBox(height: 4),
                                        const Text('Upload', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Preview - picked image bytes
                          if (_pickedImageBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Image.memory(_pickedImageBytes!, width: 100, height: 100, fit: BoxFit.cover),
                                  if (_mediaUrl != null)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          // Preview - existing image URL (when editing)
                          else if (_mediaUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Image.network(_mediaUrl!, width: 100, height: 100, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                            width: 100,
                                            height: 100,
                                            color: Colors.grey[100],
                                            child: const Icon(Icons.broken_image, color: AppColors.textHint),
                                          )),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Map ──
                      const Text('Pin Location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      const Text('Click to place the marker',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 160,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: _location,
                              initialZoom: 10.0,
                              onTap: (_, point) => setState(() => _location = point),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.ecoguide.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _location,
                                    width: 36,
                                    height: 36,
                                    child: const Icon(Icons.location_pin, color: AppColors.error, size: 36),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${_location.latitude.toStringAsFixed(5)}, ${_location.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Name + Category ──
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('POI Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Ancient Oak Grove',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<PoiType>(
                                  value: _selectedType,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  items: PoiType.values.map((t) {
                                    return DropdownMenuItem(value: t, child: Text(_typeLabel(t)));
                                  }).toList(),
                                  onChanged: (v) => setState(() => _selectedType = v ?? PoiType.flora),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Description ──
                      const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Educational details about this point...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Status ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Switch(
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v),
                              activeColor: AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isActive ? 'Active — Visible to public' : 'Draft — Hidden from public',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: _isActive ? AppColors.success : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Dialog Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider.withOpacity(0.3))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isEditing ? Icons.save : Icons.add_location, size: 18),
                              const SizedBox(width: 8),
                              Text(isEditing ? 'Update POI' : 'Create POI'),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(PoiType type) {
    switch (type) {
      case PoiType.viewpoint: return 'Viewpoint';
      case PoiType.flora: return 'Flora';
      case PoiType.fauna: return 'Fauna';
      case PoiType.historical: return 'Heritage';
      case PoiType.water: return 'Water';
      case PoiType.camping: return 'Camping';
      case PoiType.danger: return 'Danger';
      case PoiType.rest_area: return 'Rest Area';
      case PoiType.information: return 'Information';
    }
  }
}



