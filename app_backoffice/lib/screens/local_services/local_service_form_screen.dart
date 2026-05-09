import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/local_services_provider.dart';
import '../../core/models/local_service_model.dart';
import '../../core/services/local_service_api_service.dart';
import '../../core/constants/app_colors.dart';

class LocalServiceFormScreen extends StatefulWidget {
  final String? serviceId;

  const LocalServiceFormScreen({super.key, this.serviceId});

  @override
  State<LocalServiceFormScreen> createState() => _LocalServiceFormScreenState();
}

class _LocalServiceFormScreenState extends State<LocalServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _imageUrlController = TextEditingController();

  ServiceCategory _category = ServiceCategory.guide;
  bool _isVerified = false;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingService = false;
  List<String> _languages = [];

  bool get isEditing => widget.serviceId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadService();
    }
  }

  Future<void> _loadService() async {
    setState(() => _isLoadingService = true);
    try {
      final service = await LocalServiceApiService.getService(widget.serviceId!);
      _nameController.text = service.name;
      _descriptionController.text = service.description;
      _contactController.text = service.contact ?? '';
      _emailController.text = service.email ?? '';
      _websiteController.text = service.website ?? '';
      _addressController.text = service.address ?? '';
      _latitudeController.text = service.latitude?.toString() ?? '';
      _longitudeController.text = service.longitude?.toString() ?? '';
      _imageUrlController.text = service.imageUrl ?? '';
      _category = service.category;
      _isVerified = service.isVerified;
      _isActive = service.isActive;
      _languages = service.languages ?? [];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    }
    setState(() => _isLoadingService = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _category.name,
      'contact': _contactController.text.trim().isNotEmpty
          ? _contactController.text.trim()
          : null,
      'email': _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      'website': _websiteController.text.trim().isNotEmpty
          ? _websiteController.text.trim()
          : null,
      'address': _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      'latitude': _latitudeController.text.isNotEmpty
          ? double.parse(_latitudeController.text)
          : null,
      'longitude': _longitudeController.text.isNotEmpty
          ? double.parse(_longitudeController.text)
          : null,
      'imageUrl': _imageUrlController.text.trim().isNotEmpty
          ? _imageUrlController.text.trim()
          : null,
      'languages': _languages.isNotEmpty ? _languages : null,
      'isVerified': _isVerified,
      'isActive': _isActive,
    };

    final provider = context.read<LocalServicesProvider>();
    bool success;

    if (isEditing) {
      success = await provider.updateService(widget.serviceId!, data);
    } else {
      success = await provider.createService(data);
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Service modifie' : 'Service cree'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/local-services');
    } else if (provider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingService) {
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
                onPressed: () => context.go('/local-services'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'Modifier le service' : 'Nouveau service',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                      label: 'Nom du service',
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
                    _buildCategoryDropdown(),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Contact', [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _contactController,
                            label: 'Telephone',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _websiteController,
                      label: 'Site web',
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Localisation', [
                    _buildTextField(
                      controller: _addressController,
                      label: 'Adresse',
                    ),
                    const SizedBox(height: 16),
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
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Media', [
                    _buildTextField(
                      controller: _imageUrlController,
                      label: 'URL de l\'image',
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Langues parlees', [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Francais', 'Arabe', 'Anglais', 'Espagnol', 'Allemand']
                          .map((lang) => FilterChip(
                                label: Text(lang),
                                selected: _languages.contains(lang),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _languages.add(lang);
                                    } else {
                                      _languages.remove(lang);
                                    }
                                  });
                                },
                              ))
                          .toList(),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Statut', [
                    SwitchListTile(
                      title: const Text('Service verifie'),
                      subtitle: const Text('Indique que le service a ete verifie'),
                      value: _isVerified,
                      onChanged: (v) => setState(() => _isVerified = v),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile(
                      title: const Text('Service actif'),
                      subtitle: const Text('Les services inactifs ne sont pas visibles'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      activeColor: AppColors.primary,
                    ),
                  ]),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => context.go('/local-services'),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
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

  Widget _buildCategoryDropdown() {
    final categories = {
      ServiceCategory.guide: 'Guide',
      ServiceCategory.artisan: 'Artisan',
      ServiceCategory.accommodation: 'Hebergement',
      ServiceCategory.restaurant: 'Restaurant',
      ServiceCategory.transport: 'Transport',
      ServiceCategory.equipment: 'Equipement',
    };

    return DropdownButtonFormField<ServiceCategory>(
      value: _category,
      decoration: InputDecoration(
        labelText: 'Categorie',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: ServiceCategory.values.map((c) {
        return DropdownMenuItem(value: c, child: Text(categories[c] ?? c.name));
      }).toList(),
      onChanged: (v) => setState(() => _category = v ?? ServiceCategory.guide),
    );
  }
}
