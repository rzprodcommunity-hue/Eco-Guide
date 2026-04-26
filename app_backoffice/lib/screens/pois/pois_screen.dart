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
  
  // Form State
  PoiModel? _editingPoi;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  PoiType _selectedType = PoiType.flora;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isUploading = false;
  LatLng _selectedLocation = const LatLng(45.4215, -75.6972); // Default to Ottawa
  String? _mediaUrl;
  Uint8List? _pickedImageBytes;

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
    _nameController.dispose();
    _descriptionController.dispose();
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
        if (_editingPoi?.id == poi.id) _resetForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marker deleted'), backgroundColor: AppColors.success),
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
            content: Text(_editingPoi != null ? 'POI updated successfully!' : 'POI created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        provider.loadPois(type: _selectedFilter);
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

  LatLng get _location => _selectedLocation;

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Points of Interest Management',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Manage markers, educational content, and geographic assets',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New POI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  elevation: 0,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Search & Category Filters ──
          _buildSearchAndFilters(provider),
          const SizedBox(height: 24),

          // ── Main Content Area ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (Map & Form)
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
              // Right Column (List)
              Expanded(
                flex: 8,
                child: _buildExistingMarkers(provider),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(PoisProvider provider) {
    final categories = [
      {'label': 'All', 'value': null},
      {'label': 'Fauna', 'value': 'fauna'},
      {'label': 'Flora', 'value': 'flora'},
      {'label': 'Heritage', 'value': 'historical'},
    ];

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search markers by name or category...',
              hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppColors.textHint, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        const SizedBox(width: 24),
        ...categories.map((cat) {
          final isSelected = _selectedFilter == cat['value'];
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider.withOpacity(0.5)),
                  ),
                  child: Text(
                    cat['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMapCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 320,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _selectedLocation,
                  initialZoom: 13.0,
                  onTap: (tapPosition, point) {
                    setState(() => _selectedLocation = point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'com.ecoguide.app',
                  ),
                  MarkerLayer(
                    markers: [
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider.withOpacity(0.3))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Location: ${_selectedLocation.latitude.toStringAsFixed(4)}° N, ${_selectedLocation.longitude.toStringAsFixed(4)}° W',
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500, fontSize: 13),
                ),
                const Text(
                  'Click map to set marker',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoiDetailsForm() {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('POI Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                Row(
                  children: [
                    Text('Active', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('POI Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Ancient Oak Grove',
                          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.divider)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.divider)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(' ', style: TextStyle(fontSize: 13)), // Spacer to align
                      const SizedBox(height: 8),
                      DropdownButtonFormField<PoiType>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.divider)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.divider)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: PoiType.values.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(_getTypeLabel(type), style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B))),
                        )).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedType = v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Educational details about this point...',
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.divider)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.divider)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Gallery Images', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
                ElevatedButton(
                  onPressed: _isSaving ? null : _savePoi,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: 0,
                  ),
                  child: _isSaving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.camera_alt, color: AppColors.textHint, size: 24),
                              SizedBox(height: 4),
                              Text('Upload', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                            ],
                          ),
                  ),
                ),
                if (_pickedImageBytes != null) ...[
                  const SizedBox(width: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_pickedImageBytes!, width: 80, height: 80, fit: BoxFit.cover),
                  ),
                ] else if (_mediaUrl != null && _mediaUrl!.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(_mediaUrl!, width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: () => setState(() => _mediaUrl = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
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

  Widget _buildExistingMarkers(PoisProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Existing Markers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ),
          Divider(height: 1, color: AppColors.divider.withOpacity(0.5)),
          // List
          SizedBox(
            height: 600, // Fixed height or flexible based on constraints
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.pois.isEmpty
                    ? const Center(child: Text('No markers found.', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.pois.length,
                        separatorBuilder: (_, __) => Divider(height: 24, color: AppColors.divider.withOpacity(0.3)),
                        itemBuilder: (context, index) {
                          final poi = provider.pois[index];
                          final isSelected = _editingPoi?.id == poi.id;
                          return Container(
                            color: isSelected ? Colors.grey.shade50 : Colors.transparent,
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: poi.mediaUrl != null
                                      ? Image.network(poi.mediaUrl!, width: 48, height: 48, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _buildPoiPlaceholder(poi.type))
                                      : _buildPoiPlaceholder(poi.type),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(poi.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis, maxLines: 1),
                                      const SizedBox(height: 2),
                                      Text(_getTypeLabel(poi.type), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                // Status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: poi.isActive ? AppColors.success.withOpacity(0.15) : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: poi.isActive ? AppColors.success.withOpacity(0.3) : Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    poi.isActive ? 'Active' : 'Draft',
                                    style: TextStyle(color: poi.isActive ? AppColors.success : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _editPoi(poi),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _deletePoi(poi),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Divider(height: 1, color: AppColors.divider.withOpacity(0.5)),
          // Pagination
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20, color: AppColors.textSecondary),
                  onPressed: provider.currentPage > 1 ? () => provider.loadPois(page: provider.currentPage - 1, type: _selectedFilter) : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Text('Page ${provider.currentPage} of ${provider.totalPages == 0 ? 1 : provider.totalPages}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
                  onPressed: provider.currentPage < provider.totalPages ? () => provider.loadPois(page: provider.currentPage + 1, type: _selectedFilter) : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoiPlaceholder(PoiType type) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.landscape, color: AppColors.textHint, size: 24),
    );
  }

  String _getTypeLabel(PoiType type) {
    switch (type) {
      case PoiType.historical: return 'Heritage';
      case PoiType.flora: return 'Flora';
      case PoiType.fauna: return 'Fauna';
      case PoiType.viewpoint: return 'Viewpoint';
      case PoiType.water: return 'Water';
      case PoiType.camping: return 'Camping';
      case PoiType.danger: return 'Danger';
      case PoiType.rest_area: return 'Rest Area';
      case PoiType.information: return 'Information';
      default: return type.name;
    }
  }
}
