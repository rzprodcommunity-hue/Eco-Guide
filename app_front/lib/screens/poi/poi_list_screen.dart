import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_banner.dart';
import '../../providers/poi_provider.dart';
import '../../models/poi.dart';
import '../map/map_screen.dart';
import 'poi_detail_screen.dart';

class PoiListScreen extends StatefulWidget {
  const PoiListScreen({super.key});

  @override
  State<PoiListScreen> createState() => _PoiListScreenState();
}

class _PoiListScreenState extends State<PoiListScreen> {
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoiProvider>().loadPois();
    });
  }

  IconData _getPoiIcon(String type) {
    switch (type) {
      case 'viewpoint':
        return Icons.landscape;
      case 'flora':
        return Icons.local_florist;
      case 'fauna':
        return Icons.pets;
      case 'historical':
        return Icons.museum;
      case 'water':
        return Icons.water_drop;
      case 'camping':
        return Icons.cabin;
      case 'danger':
        return Icons.warning;
      case 'rest_area':
        return Icons.chair;
      case 'information':
        return Icons.info;
      default:
        return Icons.place;
    }
  }

  Future<void> _onFilterSelected(String? type) async {
    setState(() => _selectedType = type);
    await context.read<PoiProvider>().loadPois(type: type);
  }

  Future<void> _openLearnMore(BuildContext context, Poi poi) async {
    final link = poi.learnMoreUrl;
    if (link == null || link.trim().isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PoiDetailScreen(poi: poi)),
      );
      return;
    }

    final uri = Uri.tryParse(link.trim());
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lien invalide pour ce POI')),
      );
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossible d ouvrir ce lien')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PoiProvider>();
    final pois = provider.pois;
    final availableTypes = {for (final poi in pois) poi.type}.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Heritage'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.search),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadPois(type: _selectedType),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          children: [
            const Text(
              'Discover the wonders of the Vercors ecosystem',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TypeFilterChip(
                    label: 'All',
                    icon: Icons.apps,
                    isSelected: _selectedType == null,
                    onTap: () => _onFilterSelected(null),
                  ),
                  ...availableTypes.map(
                    (type) => _TypeFilterChip(
                      label: _formatType(type),
                      icon: _getPoiIcon(type),
                      isSelected: _selectedType == type,
                      onTap: () => _onFilterSelected(type),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (provider.error != null && provider.error!.isNotEmpty)
              ErrorBanner(
                message: provider.error!,
                onRetry: () => provider.loadPois(type: _selectedType),
                onDismiss: provider.clearError,
              ),
            if (provider.isLoading && pois.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (pois.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: Text('No points of interest found for this category.'),
                ),
              )
            else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Near Your Current Trail',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              ...List.generate(
                pois.length,
                (index) => _PoiHeritageCard(
                  poi: pois[index],
                  icon: _getPoiIcon(pois[index].type),
                  isHighlighted: index == 0,
                  onTapLearnMore: () => _openLearnMore(context, pois[index]),
                ),
              ),
              _InteractiveMapCard(
                center: LatLng(pois.first.latitude, pois.first.longitude),
                onTapOpenMap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapScreen()),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatType(String type) {
    return type
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}

class _PoiHeritageCard extends StatelessWidget {
  final Poi poi;
  final IconData icon;
  final bool isHighlighted;
  final VoidCallback onTapLearnMore;

  const _PoiHeritageCard({
    required this.poi,
    required this.icon,
    required this.isHighlighted,
    required this.onTapLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isHighlighted
        ? const Color(0xFFE194C6)
        : const Color(0xFFE8E0D3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EFE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isHighlighted ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PoiDetailScreen(poi: poi)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 126,
                      width: double.infinity,
                      child: poi.mediaUrl != null
                          ? CachedNetworkImage(
                              imageUrl: poi.mediaUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _FallbackPoiImage(icon: icon),
                            )
                          : _FallbackPoiImage(icon: icon),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            poi.typeDisplayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                poi.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                poi.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, height: 1.3),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      poi.badge?.trim().isNotEmpty == true
                          ? poi.badge!
                          : 'Natural Heritage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onTapLearnMore,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: const Text('Learn More'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FallbackPoiImage extends StatelessWidget {
  final IconData icon;

  const _FallbackPoiImage({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.7),
            const Color(0xFF91B67E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Icon(icon, color: Colors.white, size: 44)),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeFilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? AppTheme.primaryColor : const Color(0xFFF4EEE2);
    final fg = isSelected ? Colors.white : const Color(0xFF3B3024);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFD6CAB8)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractiveMapCard extends StatelessWidget {
  final LatLng center;
  final VoidCallback onTapOpenMap;

  const _InteractiveMapCard({required this.center, required this.onTapOpenMap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 22),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE9DD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDCFBD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 4),
            minVerticalPadding: 0,
            title: Text(
              'Interactive POI Map',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Text('Find more points nearby'),
            leading: Icon(Icons.map_outlined),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 120,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 12,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ecoguide.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        child: const Icon(
                          Icons.place,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onTapOpenMap,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open Map'),
            ),
          ),
        ],
      ),
    );
  }
}
