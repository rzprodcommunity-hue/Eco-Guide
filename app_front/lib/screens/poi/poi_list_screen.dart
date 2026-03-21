import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_banner.dart';
import '../../providers/poi_provider.dart';
import '../../models/poi.dart';
import 'poi_detail_screen.dart';

class PoiListScreen extends StatefulWidget {
  const PoiListScreen({super.key});

  @override
  State<PoiListScreen> createState() => _PoiListScreenState();
}

class _PoiListScreenState extends State<PoiListScreen> {
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
        return Icons.photo_camera;
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PoiProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Points d\'interet'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              provider.loadPois(type: value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Tous'),
              ),
              ...AppConstants.poiTypes.map(
                (type) => PopupMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(_getPoiIcon(type), size: 18),
                      const SizedBox(width: 8),
                      Text(_formatType(type)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (provider.error != null && provider.error!.isNotEmpty)
            ErrorBanner(
              message: provider.error!,
              onRetry: provider.loadPois,
              onDismiss: provider.clearError,
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await provider.loadPois();
              },
              child: provider.isLoading && provider.pois.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.pois.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.place_outlined,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Aucun point d\'interet trouve'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.pois.length,
                          itemBuilder: (context, index) {
                            final poi = provider.pois[index];
                            return _PoiCard(poi: poi, icon: _getPoiIcon(poi.type));
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatType(String type) {
    return type
        .split('_')
        .map((part) =>
            part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _PoiCard extends StatelessWidget {
  final Poi poi;
  final IconData icon;

  const _PoiCard({required this.poi, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PoiDetailScreen(poi: poi)),
          );
        },
        leading: poi.mediaUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: poi.mediaUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _iconContainer(icon),
                ),
              )
            : _iconContainer(icon),
        title: Text(
          poi.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          poi.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _iconContainer(IconData icon) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppTheme.primaryColor),
    );
  }
}
