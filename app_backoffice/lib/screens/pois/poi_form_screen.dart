import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/pois_provider.dart';
import '../../core/models/poi_model.dart';
import '../../core/services/poi_service.dart';
import '../../core/constants/app_colors.dart';

class PoiFormScreen extends StatefulWidget {
  final String? poiId;

  const PoiFormScreen({super.key, this.poiId});

  @override
  State<PoiFormScreen> createState() => _PoiFormScreenState();
}

class _PoiFormScreenState extends State<PoiFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _mediaUrlController = TextEditingController();
  final _audioGuideUrlController = TextEditingController();

  PoiType _type = PoiType.viewpoint;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingPoi = false;

  bool get isEditing => widget.poiId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadPoi();
    }
  }

  Future<void> _loadPoi() async {
    setState(() => _isLoadingPoi = true);
    try {
      final poi = await PoiService.getPoi(widget.poiId!);
      _nameController.text = poi.name;
      _descriptionController.text = poi.description;
      _latitudeController.text = poi.latitude.toString();
      _longitudeController.text = poi.longitude.toString();
      _mediaUrlController.text = poi.mediaUrl ?? '';
      _audioGuideUrlController.text = poi.audioGuideUrl ?? '';
      _type = poi.type;
      _isActive = poi.isActive;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    }
    setState(() => _isLoadingPoi = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _mediaUrlController.dispose();
    _audioGuideUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'type': _type.name,
      'latitude': double.parse(_latitudeController.text),
      'longitude': double.parse(_longitudeController.text),
      'mediaUrl': _mediaUrlController.text.trim().isNotEmpty
          ? _mediaUrlController.text.trim()
          : null,
      'audioGuideUrl': _audioGuideUrlController.text.trim().isNotEmpty
          ? _audioGuideUrlController.text.trim()
          : null,
      'isActive': _isActive,
    };

    final provider = context.read<PoisProvider>();
    bool success;

    if (isEditing) {
      success = await provider.updatePoi(widget.poiId!, data);
    } else {
      success = await provider.createPoi(data);
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'POI modifie' : 'POI cree'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/pois');
    } else if (provider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPoi) {
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
                onPressed: () => context.go('/pois'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'Modifier le POI' : 'Nouveau POI',
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
                      label: 'Nom du POI',
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
                    _buildTypeDropdown(),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Localisation', [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _latitudeController,
                            label: 'Latitude',
                            keyboardType: TextInputType.number,
                            validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _longitudeController,
                            label: 'Longitude',
                            keyboardType: TextInputType.number,
                            validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Medias', [
                    _buildTextField(
                      controller: _mediaUrlController,
                      label: 'URL de l\'image',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _audioGuideUrlController,
                      label: 'URL du guide audio',
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Statut', [
                    SwitchListTile(
                      title: const Text('POI actif'),
                      subtitle: const Text('Les POI inactifs ne sont pas visibles'),
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
                        onPressed: () => context.go('/pois'),
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

  Widget _buildTypeDropdown() {
    final types = {
      PoiType.viewpoint: 'Point de vue',
      PoiType.flora: 'Flore',
      PoiType.fauna: 'Faune',
      PoiType.historical: 'Historique',
      PoiType.water: 'Point d\'eau',
      PoiType.camping: 'Camping',
      PoiType.danger: 'Danger',
      PoiType.rest_area: 'Aire de repos',
      PoiType.information: 'Information',
    };

    return DropdownButtonFormField<PoiType>(
      value: _type,
      decoration: InputDecoration(
        labelText: 'Type',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: PoiType.values.map((t) {
        return DropdownMenuItem(value: t, child: Text(types[t] ?? t.name));
      }).toList(),
      onChanged: (v) => setState(() => _type = v ?? PoiType.viewpoint),
    );
  }
}
