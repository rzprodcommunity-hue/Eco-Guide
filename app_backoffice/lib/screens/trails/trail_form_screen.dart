import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/providers/trails_provider.dart';
import '../../core/models/trail_model.dart';
import '../../core/services/trail_service.dart';
import '../../core/constants/app_colors.dart';

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

  bool get isEditing => widget.trailId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadTrail();
    }
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
      _difficulty = trail.difficulty;
      _isActive = trail.isActive;
      _geojson = trail.geojson;
      _imageUrls = trail.imageUrls ?? [];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
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
    super.dispose();
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
        setState(() => _geojson = json);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GeoJSON importe avec succes')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: Fichier GeoJSON invalide'), backgroundColor: AppColors.error),
        );
      }
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
      'isActive': _isActive,
    };

    final provider = context.read<TrailsProvider>();
    bool success;

    if (isEditing) {
      success = await provider.updateTrail(widget.trailId!, data);
    } else {
      success = await provider.createTrail(data);
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Sentier modifie' : 'Sentier cree'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/trails');
    } else if (provider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: AppColors.error),
      );
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
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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
                  _buildSection('Caracteristiques', [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _distanceController,
                            label: 'Distance (km)',
                            keyboardType: TextInputType.number,
                            validator: (v) => v?.isEmpty == true ? 'Requis' : null,
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
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Trace GeoJSON', [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickGeoJson,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Importer GeoJSON'),
                        ),
                        const SizedBox(width: 16),
                        if (_geojson != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, color: AppColors.success, size: 18),
                                SizedBox(width: 8),
                                Text('GeoJSON charge', style: TextStyle(color: AppColors.success)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Statut', [
                    SwitchListTile(
                      title: const Text('Sentier actif'),
                      subtitle: const Text('Les sentiers inactifs ne sont pas visibles'),
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
                        onPressed: () => context.go('/trails'),
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

  Widget _buildDifficultyDropdown() {
    return DropdownButtonFormField<TrailDifficulty>(
      value: _difficulty,
      decoration: InputDecoration(
        labelText: 'Difficulte',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: TrailDifficulty.values.map((d) {
        return DropdownMenuItem(
          value: d,
          child: Text(d == TrailDifficulty.easy
              ? 'Facile'
              : d == TrailDifficulty.moderate
                  ? 'Modere'
                  : 'Difficile'),
        );
      }).toList(),
      onChanged: (v) => setState(() => _difficulty = v ?? TrailDifficulty.moderate),
    );
  }
}
