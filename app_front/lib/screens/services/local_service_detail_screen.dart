import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/eco_shortcut_badge.dart';
import '../../models/local_service.dart';
import '../../providers/local_service_provider.dart';
import '../home/home_screen.dart';
import '../map/navigation_sos_screen.dart';

class LocalServiceDetailScreen extends StatefulWidget {
  final String serviceId;
  final LocalService fallbackService;

  const LocalServiceDetailScreen({
    super.key,
    required this.serviceId,
    required this.fallbackService,
  });

  @override
  State<LocalServiceDetailScreen> createState() => _LocalServiceDetailScreenState();
}

class _LocalServiceDetailScreenState extends State<LocalServiceDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalServiceProvider>().loadServiceById(widget.serviceId);
    });
  }

  LocalService _serviceFromProvider(LocalServiceProvider provider) {
    final selected = provider.selectedService;
    if (selected != null && selected.id == widget.serviceId) {
      return selected;
    }
    return widget.fallbackService;
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'guide':
        return Icons.person;
      case 'artisan':
        return Icons.handyman;
      case 'accommodation':
        return Icons.hotel;
      case 'restaurant':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'equipment':
        return Icons.backpack;
      default:
        return Icons.store;
    }
  }

  Future<void> _openExternal(String value, String prefix) async {
    final url = value.trim();
    if (url.isEmpty) return;

    final uri = prefix.isEmpty
        ? Uri.tryParse(url.startsWith('http') ? url : 'https://$url')
        : Uri.tryParse('$prefix$url');
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocalServiceProvider>();
    final service = _serviceFromProvider(provider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2EC),
      bottomNavigationBar: EcoShortcutBadge(
        currentTab: EcoShortcutTab.services,
        onTabSelected: (tab) {
          final index = switch (tab) {
            EcoShortcutTab.home => 0,
            EcoShortcutTab.map => 1,
            EcoShortcutTab.trails => 2,
            EcoShortcutTab.quiz => 4,
            EcoShortcutTab.services => 6,
            EcoShortcutTab.settings => 7,
          };
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomeScreen(initialIndex: index)),
            (route) => false,
          );
        },
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: service.imageUrl != null && service.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: service.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey[300]),
                          errorWidget: (_, __, ___) => _buildHeroPlaceholder(service),
                        )
                      : _buildHeroPlaceholder(service),
                ),
                Container(
                  height: 300,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xAA000000)],
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircleIconButton(
                        icon: Icons.arrow_back_ios_new,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      if (provider.isLoading)
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          service.categoryDisplayName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        service.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              service.address ?? 'Adresse non disponible',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (service.rating != null) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.star, color: Color(0xFFF5A623), size: 16),
                            const SizedBox(width: 3),
                            Text(
                              '${service.rating!.toStringAsFixed(1)} (${service.reviewCount} avis)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE3D8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFDCCFBF)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FactBox(
                            icon: _getCategoryIcon(service.category),
                            label: 'Categorie',
                            value: service.categoryDisplayName,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FactBox(
                            icon: Icons.verified,
                            label: 'Statut',
                            value: service.isVerified ? 'Verifie' : 'Non verifie',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'A propos du service',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    service.description,
                    style: const TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 16,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: service.latitude == null || service.longitude == null
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NavigationSosScreen(
                                    destination: LatLng(service.latitude!, service.longitude!),
                                    destinationLabel: service.name,
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.route),
                      label: const Text('Directions sur la carte'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Informations',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (service.address != null)
                    _InfoTile(
                      icon: Icons.location_on,
                      title: 'Adresse',
                      value: service.address!,
                    ),
                  if (service.email != null)
                    _InfoTile(
                      icon: Icons.mail_outline,
                      title: 'Email',
                      value: service.email!,
                    ),
                  if (service.website != null)
                    _InfoTile(
                      icon: Icons.language,
                      title: 'Site web',
                      value: service.website!,
                    ),
                  if (service.languages != null && service.languages!.isNotEmpty)
                    _InfoTile(
                      icon: Icons.translate,
                      title: 'Langues',
                      value: service.languages!.join(', '),
                    ),
                  const SizedBox(height: 18),
                  if (service.latitude != null && service.longitude != null) ...[
                    const Text(
                      'Localisation',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 160,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(service.latitude!, service.longitude!),
                            initialZoom: 14,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                              userAgentPackageName: 'com.ecoguide.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(service.latitude!, service.longitude!),
                                  child: const Icon(Icons.place, color: AppTheme.primaryColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (service.additionalImages != null && service.additionalImages!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Galerie',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: service.additionalImages!.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final image = service.additionalImages![index];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: image,
                              width: 150,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 150,
                                color: Colors.grey[300],
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 150,
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPlaceholder(LocalService service) {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.18),
      child: Center(
        child: Icon(
          _getCategoryIcon(service.category),
          size: 64,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF111111)),
      ),
    );
  }
}

class _FactBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _FactBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2ECE2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD3C6B5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF171717),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4D9C9)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F1F1F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Color(0xFF666666), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
