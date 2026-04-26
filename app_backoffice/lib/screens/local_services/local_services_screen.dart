import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/providers/local_services_provider.dart';
import '../../core/models/local_service_model.dart';
import '../../core/constants/app_colors.dart';

class LocalServicesScreen extends StatefulWidget {
  const LocalServicesScreen({super.key});

  @override
  State<LocalServicesScreen> createState() => _LocalServicesScreenState();
}

class _LocalServicesScreenState extends State<LocalServicesScreen> {
  // Form State
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  ServiceCategory _category = ServiceCategory.accommodation;
  String? _editingId;
  LatLng _selectedLocation = const LatLng(31.6295, -7.9811); // Marrakech default

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalServicesProvider>().loadServices();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _editService(LocalServiceModel service) {
    setState(() {
      _editingId = service.id;
      _nameController.text = service.name;
      _contactController.text = service.contact ?? '';
      _websiteController.text = service.website ?? '';
      _descriptionController.text = service.description;
      _addressController.text = service.address ?? '';
      _latitudeController.text = service.latitude?.toString() ?? '';
      _longitudeController.text = service.longitude?.toString() ?? '';
      _category = service.category;
      
      if (service.latitude != null && service.longitude != null) {
        _selectedLocation = LatLng(service.latitude!, service.longitude!);
      } else {
        _selectedLocation = const LatLng(31.6295, -7.9811);
      }
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _contactController.clear();
      _websiteController.clear();
      _descriptionController.clear();
      _addressController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      _category = ServiceCategory.accommodation;
      _selectedLocation = const LatLng(31.6295, -7.9811);
    });
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<LocalServicesProvider>();

    final data = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _category.name,
      'contact': _contactController.text.trim().isNotEmpty ? _contactController.text.trim() : null,
      'website': _websiteController.text.trim().isNotEmpty ? _websiteController.text.trim() : null,
      'address': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
      'latitude': _latitudeController.text.isNotEmpty ? double.parse(_latitudeController.text) : null,
      'longitude': _longitudeController.text.isNotEmpty ? double.parse(_longitudeController.text) : null,
      'isActive': true,
      'isVerified': true,
    };

    bool success;
    if (_editingId != null) {
      success = await provider.updateService(_editingId!, data);
    } else {
      success = await provider.createService(data);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingId != null ? 'Business updated' : 'Business created'),
          backgroundColor: AppColors.success,
        ),
      );
      _resetForm();
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to save business'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteService(LocalServiceModel service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${service.name}?'),
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
      await context.read<LocalServicesProvider>().deleteService(service.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocalServicesProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Local Economy Directory',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Manage local guides, artisans, and eco-lodges supporting the trail network.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.add),
                label: const Text('Add New Business'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildStatsCards(provider),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Form
              Expanded(flex: 2, child: _buildFormCard(provider.isLoading)),
              const SizedBox(width: 24),
              // Right: Table
              Expanded(flex: 3, child: _buildTableCard(provider)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatsCards(LocalServicesProvider provider) {
    final total = provider.total;
    int guides = 0;
    int lodges = 0;
    int artisans = 0;

    for (var svc in provider.services) {
      if (svc.category == ServiceCategory.guide) guides++;
      if (svc.category == ServiceCategory.accommodation) lodges++;
      if (svc.category == ServiceCategory.artisan) artisans++;
    }

    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Partners', total.toString(), '+12%', true)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Active Guides', guides.toString(), '+4%', true)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Eco-Lodges', lodges.toString(), 'Stable', false)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Artisans', artisans.toString(), '+2', true)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String change, bool isPositive) {
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
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive ? AppColors.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    color: isPositive ? AppColors.success : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(bool isLoading) {
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
            const Text('Business Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Business Name', border: OutlineInputBorder()),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<ServiceCategory>(
                    value: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: ServiceCategory.values.map((c) {
                      String label = c.name;
                      if (c == ServiceCategory.accommodation) label = 'Eco-Lodge';
                      if (c == ServiceCategory.guide) label = 'Guide';
                      if (c == ServiceCategory.artisan) label = 'Artisan';
                      if (c == ServiceCategory.restaurant) label = 'Cafe/Restaurant';
                      return DropdownMenuItem(value: c, child: Text(label));
                    }).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(labelText: 'Phone or Email', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _websiteController,
                    decoration: const InputDecoration(labelText: 'Website', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            const Text('Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 10.0,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLocation = point;
                        _latitudeController.text = point.latitude.toString();
                        _longitudeController.text = point.longitude.toString();
                      });
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
            const SizedBox(height: 24),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _longitudeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _resetForm,
                  child: const Text('Cancel', style: TextStyle(color: AppColors.success)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: isLoading ? null : _saveService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(_editingId != null ? 'Update Business' : 'Save Business'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(LocalServicesProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search directory...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Text('Filter'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_drop_down),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          if (provider.isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (provider.services.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No businesses found.')))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.services.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final service = provider.services[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: service.imageUrl != null
                            ? Image.network(service.imageUrl!, width: 48, height: 48, fit: BoxFit.cover)
                            : Container(width: 48, height: 48, color: Colors.grey[200], child: const Icon(Icons.store)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              service.category.name.toUpperCase(),
                              style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          service.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            const Icon(Icons.phone, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                service.contact ?? 'N/A',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _editService(service),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _deleteService(service),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${provider.services.length} of ${provider.total} entries',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: provider.currentPage > 1 ? () => provider.loadServices(page: provider.currentPage - 1) : null,
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(4)),
                    child: Text(provider.currentPage.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: provider.currentPage < provider.totalPages ? () => provider.loadServices(page: provider.currentPage + 1) : null,
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}
