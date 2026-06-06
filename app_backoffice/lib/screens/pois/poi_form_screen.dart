import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/pois_provider.dart';
import '../../core/models/poi_model.dart';
import '../../core/models/trail_model.dart';
import '../../core/services/poi_service.dart';
import '../../core/services/trail_service.dart';
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
  final _badgeController = TextEditingController();
  final _learnMoreUrlController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _mediaUrlController = TextEditingController();
  final _audioGuideUrlController = TextEditingController();

  PoiType _type = PoiType.viewpoint;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingPoi = false;
  bool _isLocating = false;
  LatLng? _markerLocation;

  String? _selectedTrailId;
  List<TrailModel> _trails = [];
  bool _isLoadingTrails = false;

  bool get isEditing => widget.poiId != null;

  @override
  void initState() {
    super.initState();
    _loadTrails();
    if (isEditing) {
      _loadPoi();
    }
  }

  Future<void> _loadTrails() async {
    setState(() => _isLoadingTrails = true);
    try {
      final result = await TrailService.getTrails(limit: 1000);
      if (!mounted) return;
      setState(() {
        _trails = (result['trails'] as List).cast<TrailModel>();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur chargement sentiers: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoadingTrails = false);
  }

  Future<void> _loadPoi() async {
    setState(() => _isLoadingPoi = true);
    try {
      final poi = await PoiService.getPoi(widget.poiId!);
      _nameController.text = poi.name;
      _descriptionController.text = poi.description;
      _badgeController.text = poi.badge ?? '';
      _learnMoreUrlController.text = poi.learnMoreUrl ?? '';
      _latitudeController.text = poi.latitude.toString();
      _longitudeController.text = poi.longitude.toString();
      _markerLocation = LatLng(poi.latitude, poi.longitude);
      _mediaUrlController.text = poi.mediaUrl ?? '';
      _audioGuideUrlController.text = poi.audioGuideUrl ?? '';
      _type = poi.type;
      _isActive = poi.isActive;
      _selectedTrailId = poi.trailId;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    setState(() => _isLoadingPoi = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _badgeController.dispose();
    _learnMoreUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _mediaUrlController.dispose();
    _audioGuideUrlController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
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
      setState(() {
        _latitudeController.text = pos.latitude.toStringAsFixed(6);
        _longitudeController.text = pos.longitude.toStringAsFixed(6);
        _markerLocation = LatLng(pos.latitude, pos.longitude);
      });
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'badge': _badgeController.text.trim().isNotEmpty
          ? _badgeController.text.trim()
          : null,
      'learnMoreUrl': _learnMoreUrlController.text.trim().isNotEmpty
          ? _learnMoreUrlController.text.trim()
          : null,
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
      // Include trailId in the create payload (api_service strips it if null).
      data['trailId'] = _selectedTrailId;
      success = await provider.createPoi(data);
    }

    // On edit, persist the trail link directly via Supabase so that clearing it
    // to null is honored (api_service strips nulls from update payloads). On
    // create, the payload above already carries a non-null trailId, and a
    // brand-new POI has no stale link to clear — so no extra call is needed.
    if (success && isEditing) {
      try {
        await Supabase.instance.client
            .from('pois')
            .update({'trailId': _selectedTrailId}).eq('id', widget.poiId!);
      } catch (_) {
        // Non-fatal: POI was saved; trail link update failed silently.
      }
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
        SnackBar(
          content: Text(provider.error!),
          backgroundColor: AppColors.error,
        ),
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
              color: Theme.of(context).cardColor,
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
                    _buildTextField(
                      controller: _badgeController,
                      label: 'Badge (ex: Protected species)',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _learnMoreUrlController,
                      label: 'URL Learn more',
                      validator: (v) {
                        final value = v?.trim();
                        if (value == null || value.isEmpty) return null;
                        final uri = Uri.tryParse(value);
                        final isHttp =
                            uri != null &&
                            (uri.scheme == 'http' || uri.scheme == 'https') &&
                            uri.hasAuthority;
                        return isHttp ? null : 'URL invalide (http/https)';
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTypeDropdown(),
                    const SizedBox(height: 16),
                    _buildTrailDropdown(),
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
                            validator: (v) =>
                                v?.isEmpty == true ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _longitudeController,
                            label: 'Longitude',
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v?.isEmpty == true ? 'Requis' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _isLocating ? null : _useCurrentLocation,
                        icon: _isLocating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location, size: 18),
                        label: Text(_isLocating
                            ? 'Localisation...'
                            : 'Utiliser ma position GPS'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLocationMap(),
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
                      subtitle: const Text(
                        'Les POI inactifs ne sont pas visibles',
                      ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
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

  Widget _buildLocationMap() {
    if (_markerLocation == null) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                size: 48,
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 8),
              Text(
                'Appuyez sur « Utiliser ma position GPS » pour afficher\nvotre position sur la carte',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final loc = _markerLocation!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 280,
        child: FlutterMap(
          key: ValueKey('${loc.latitude},${loc.longitude}'),
          options: MapOptions(initialCenter: loc, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ecoguide.backoffice',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: loc,
                  width: 44,
                  height: 44,
                  child: const Icon(
                    Icons.location_pin,
                    color: AppColors.error,
                    size: 44,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
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

  Widget _buildTrailDropdown() {
    return DropdownButtonFormField<String?>(
      value: _selectedTrailId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Sentier associe',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: _isLoadingTrails
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Aucun sentier'),
        ),
        ..._trails.map((t) {
          return DropdownMenuItem<String?>(
            value: t.id,
            child: Text(t.name, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: (v) => setState(() => _selectedTrailId = v),
    );
  }
}
