import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/eco_shortcut_badge.dart';
import '../../core/widgets/error_banner.dart';
import '../../models/trail.dart';
import '../../models/poi.dart';
import '../../providers/poi_provider.dart';
import '../home/home_screen.dart';
import '../map/navigation_sos_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final poiProvider = context.watch<PoiProvider>();
    final rating = widget.trail.averageRating;
    final reviewCount = widget.trail.reviewCount ?? 0;
    final ratingText = rating != null ? rating.toStringAsFixed(1) : '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2EC),
      bottomNavigationBar: EcoShortcutBadge(
        currentTab: EcoShortcutTab.trails,
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
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 300,
                        width: double.infinity,
                        child:
                            widget.trail.imageUrls != null &&
                                widget.trail.imageUrls!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.trail.imageUrls!.first,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: Colors.grey[300]),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.landscape, size: 64),
                                ),
                              )
                            : Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.landscape,
                                  size: 64,
                                  color: Colors.white,
                                ),
                              ),
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
                            Row(
                              children: [
                                _CircleIconButton(
                                  icon: Icons.share_outlined,
                                  onTap: () {},
                                ),
                                const SizedBox(width: 8),
                                _CircleIconButton(
                                  icon: Icons.favorite_border,
                                  onTap: () {},
                                ),
                              ],
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
                                color: _getDifficultyColor(
                                  widget.trail.difficulty,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _getDifficultyText(
                                  widget.trail.difficulty,
                                ).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.trail.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 34,
                                height: 1.05,
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
                                    widget.trail.region ?? 'Region inconnue',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, 0),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F2EC),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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
                              color: const Color(0xFFEAE3D8),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFDCCFBF),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _DetailStatBox(
                                    icon: Icons.straighten,
                                    label: 'Distance',
                                    value: widget.trail.distanceText,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DetailStatBox(
                                    icon: Icons.schedule,
                                    label: 'Duree',
                                    value: widget.trail.durationText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'A propos du sentier',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.trail.description,
                            style: const TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 16,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: widget.trail.startLatitude == null ||
                                      widget.trail.startLongitude == null
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => NavigationSosScreen(
                                            destination: LatLng(
                                              widget.trail.startLatitude!,
                                              widget.trail.startLongitude!,
                                            ),
                                            destinationLabel: widget.trail.name,
                                            trail: widget.trail,
                                          ),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.route),
                              label: const Text('Directions sur la carte'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Points d\'interet',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111111),
                                ),
                              ),
                              Text(
                                '${poiProvider.pois.length} lieux',
                                style: const TextStyle(
                                  color: Color(0xFF666666),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (poiProvider.isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (poiProvider.pois.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Aucun point d\'interet disponible',
                                style: TextStyle(color: Color(0xFF666666)),
                              ),
                            )
                          else
                            SizedBox(
                              height: 176,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: poiProvider.pois.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  return _PoiPreviewCard(
                                    poi: poiProvider.pois[index],
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
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

class _DetailStatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailStatBox({
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
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: Color(0xFF171717),
            ),
          ),
        ],
      ),
    );
  }
}

class _PoiPreviewCard extends StatelessWidget {
  final Poi poi;

  const _PoiPreviewCard({required this.poi});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PoiDetailScreen(poi: poi)),
        );
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: const Color(0xFFEFE8DD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCCFBF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: SizedBox(
                height: 92,
                width: double.infinity,
                child: poi.mediaUrl != null && poi.mediaUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: poi.mediaUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey[300]),
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.grey[300]),
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: Icon(
                          _getPoiIcon(poi.type),
                          color: const Color(0xFF666666),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                poi.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF111111),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
              child: Text(
                poi.badge ?? poi.typeDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
