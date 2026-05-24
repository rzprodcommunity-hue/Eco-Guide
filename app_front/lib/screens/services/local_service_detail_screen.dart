import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/map_tile_url.dart';
import '../../core/widgets/eco_shortcut_badge.dart';
import '../../models/local_service.dart';
import '../../providers/local_service_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/map_offline_service.dart';
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
  State<LocalServiceDetailScreen> createState() =>
      _LocalServiceDetailScreenState();
}

class _LocalServiceDetailScreenState extends State<LocalServiceDetailScreen> {
  final MapController _mapController = MapController();
  final MapOfflineService _mapOfflineService = MapOfflineService();
  bool _navigatingToDirections = false;

  @override
  void initState() {
    super.initState();
    _mapOfflineService.initialize();
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

  // ignore: unused_element
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  child:
                      service.imageUrl != null && service.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: service.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: Colors.grey[300]),
                          errorWidget: (_, _, _) =>
                              _buildHeroPlaceholder(service),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
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
                          const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 16,
                          ),
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
                            const Icon(
                              Icons.star,
                              color: Color(0xFFF5A623),
                              size: 16,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${service.rating!.toStringAsFixed(1)} (${service.reviewCount} ${context.watch<LocaleProvider>().t('services.detail.reviews')})',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.3)
                          : const Color(0xFFEAE3D8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FactBox(
                            icon: _getCategoryIcon(service.category),
                            label: context.watch<LocaleProvider>().t('services.detail.category'),
                            value: service.categoryDisplayName,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FactBox(
                            icon: Icons.verified,
                            label: context.watch<LocaleProvider>().t('services.detail.status'),
                            value: service.isVerified
                                ? context.watch<LocaleProvider>().t('services.detail.verified')
                                : context.watch<LocaleProvider>().t('services.detail.notVerified'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    context.watch<LocaleProvider>().t('services.detail.about'),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    service.description,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 16,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (service.latitude == null ||
                              service.longitude == null ||
                              _navigatingToDirections)
                          ? null
                          : () async {
                              setState(() => _navigatingToDirections = true);
                              try {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NavigationSosScreen(
                                      destination: LatLng(
                                        service.latitude!,
                                        service.longitude!,
                                      ),
                                      destinationLabel: service.name,
                                    ),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() =>
                                      _navigatingToDirections = false);
                                }
                              }
                            },
                      icon: _navigatingToDirections
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.route),
                      label: Text(_navigatingToDirections
                          ? 'Calcul de l\'itinéraire...'
                          : context
                              .watch<LocaleProvider>()
                              .t('services.detail.directions')),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    context.watch<LocaleProvider>().t('services.detail.info'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (service.address != null)
                    _InfoTile(
                      icon: Icons.location_on,
                      title: context.watch<LocaleProvider>().t('services.detail.address'),
                      value: service.address!,
                    ),
                  if (service.email != null)
                    _InfoTile(
                      icon: Icons.mail_outline,
                      title: context.watch<LocaleProvider>().t('services.detail.email'),
                      value: service.email!,
                    ),
                  if (service.website != null)
                    _InfoTile(
                      icon: Icons.language,
                      title: context.watch<LocaleProvider>().t('services.detail.website'),
                      value: service.website!,
                    ),
                  if (service.languages != null &&
                      service.languages!.isNotEmpty)
                    _InfoTile(
                      icon: Icons.translate,
                      title: context.watch<LocaleProvider>().t('services.detail.languages'),
                      value: service.languages!.join(', '),
                    ),
                  const SizedBox(height: 18),
                  if (service.latitude != null &&
                      service.longitude != null) ...[
                    Text(
                      context.watch<LocaleProvider>().t('poi.location'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 220,
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: LatLng(
                                  service.latitude!,
                                  service.longitude!,
                                ),
                                initialZoom: 14,
                                minZoom: 5,
                                maxZoom: 18,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: mapTileUrlForTheme(context),
                                  userAgentPackageName: 'com.ecoguide.app',
                                  tileProvider: LocalFirstTileProvider(
                                    service: _mapOfflineService,
                                  ),
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(
                                        service.latitude!,
                                        service.longitude!,
                                      ),
                                      width: 44,
                                      height: 44,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 6,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          _getCategoryIcon(service.category),
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Zoom controls
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Column(
                                children: [
                                  _MapZoomButton(
                                    icon: Icons.add,
                                    onTap: () => _mapController.move(
                                      _mapController.camera.center,
                                      _mapController.camera.zoom + 1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _MapZoomButton(
                                    icon: Icons.remove,
                                    onTap: () => _mapController.move(
                                      _mapController.camera.center,
                                      _mapController.camera.zoom - 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Re-center button
                            Positioned(
                              right: 10,
                              top: 10,
                              child: _MapZoomButton(
                                icon: Icons.my_location,
                                onTap: () => _mapController.move(
                                  LatLng(
                                    service.latitude!,
                                    service.longitude!,
                                  ),
                                  14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (service.additionalImages != null &&
                      service.additionalImages!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Galerie',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: service.additionalImages!.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final image = service.additionalImages![index];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: image,
                              width: 150,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                width: 150,
                                color: Colors.grey[300],
                              ),
                              errorWidget: (_, _, _) => Container(
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
          color: Theme.of(context).cardColor.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface,
        ),
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
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
            : const Color(0xFFF2ECE2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.65),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
