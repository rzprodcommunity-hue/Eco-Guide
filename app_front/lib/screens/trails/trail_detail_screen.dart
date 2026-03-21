import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_banner.dart';
import '../../models/trail.dart';
import '../../models/poi.dart';
import '../../providers/poi_provider.dart';
import '../poi/poi_detail_screen.dart';

class TrailDetailScreen extends StatefulWidget {
  final Trail trail;

  const TrailDetailScreen({super.key, required this.trail});

  @override
  State<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends State<TrailDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoiProvider>().loadPoisByTrail(widget.trail.id);
    });
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'difficult':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getDifficultyText(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 'Facile';
      case 'moderate':
        return 'Modere';
      case 'difficult':
        return 'Difficile';
      default:
        return difficulty;
    }
  }

  List<LatLng> _getTrailCoordinates() {
    if (widget.trail.geojson == null) return [];

    try {
      final coordinates = widget.trail.geojson!['coordinates'] as List?;
      if (coordinates == null) return [];

      return coordinates.map((coord) {
        final c = coord as List;
        return LatLng(c[1] as double, c[0] as double);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final poiProvider = context.watch<PoiProvider>();
    final trailCoords = _getTrailCoordinates();
    final hasMap = widget.trail.startLatitude != null &&
                   widget.trail.startLongitude != null;

    return Scaffold(
      body: Column(
        children: [
          if (poiProvider.error != null && poiProvider.error!.isNotEmpty)
            ErrorBanner(
              message: poiProvider.error!,
              onRetry: () => poiProvider.loadPoisByTrail(widget.trail.id),
              onDismiss: poiProvider.clearError,
            ),
          Expanded(
            child: CustomScrollView(
              slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.trail.name,
                style: const TextStyle(
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
              background: widget.trail.imageUrls != null &&
                         widget.trail.imageUrls!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.trail.imageUrls!.first,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey[300]),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        child: const Icon(Icons.landscape, size: 64),
                      ),
                    )
                  : Container(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      child: const Icon(Icons.landscape, size: 64, color: Colors.white),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Difficulty and region
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(widget.trail.difficulty)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getDifficultyColor(widget.trail.difficulty),
                          ),
                        ),
                        child: Text(
                          _getDifficultyText(widget.trail.difficulty),
                          style: TextStyle(
                            color: _getDifficultyColor(widget.trail.difficulty),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (widget.trail.region != null)
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              widget.trail.region!,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stats cards
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.straighten,
                          label: 'Distance',
                          value: widget.trail.distanceText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.timer,
                          label: 'Duree',
                          value: widget.trail.durationText,
                        ),
                      ),
                      if (widget.trail.elevationGain != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.trending_up,
                            label: 'Denivele',
                            value: '${widget.trail.elevationGain!.toInt()}m',
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.trail.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Map preview
                  if (hasMap) ...[
                    Text(
                      'Carte',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 200,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              widget.trail.startLatitude!,
                              widget.trail.startLongitude!,
                            ),
                            initialZoom: 13,
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
                            if (trailCoords.isNotEmpty)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: trailCoords,
                                    strokeWidth: 4,
                                    color: AppTheme.primaryColor,
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    widget.trail.startLatitude!,
                                    widget.trail.startLongitude!,
                                  ),
                                  child: const Icon(
                                    Icons.flag,
                                    color: AppTheme.primaryColor,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // POIs
                  if (poiProvider.pois.isNotEmpty) ...[
                    Text(
                      'Points d\'interet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: poiProvider.pois.length,
                      itemBuilder: (context, index) {
                        final poi = poiProvider.pois[index];
                        return _PoiListItem(poi: poi);
                      },
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
             ) ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Navigation demarree!')),
          );
        },
        icon: const Icon(Icons.navigation),
        label: const Text('Demarrer'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PoiListItem extends StatelessWidget {
  final Poi poi;

  const _PoiListItem({required this.poi});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Icon(
            _getPoiIcon(poi.type),
            color: AppTheme.primaryColor,
          ),
        ),
        title: Text(poi.name),
        subtitle: Text(poi.typeDisplayName),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PoiDetailScreen(poi: poi),
            ),
          );
        },
      ),
    );
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
}
