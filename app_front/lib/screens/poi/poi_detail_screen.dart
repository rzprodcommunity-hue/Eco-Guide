import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/eco_shortcut_badge.dart';
import '../../models/poi.dart';
import '../home/home_screen.dart';
import '../map/navigation_sos_screen.dart';
import '../../services/map_offline_service.dart';

class PoiDetailScreen extends StatefulWidget {
  final Poi poi;

  const PoiDetailScreen({super.key, required this.poi});

  @override
  State<PoiDetailScreen> createState() => _PoiDetailScreenState();
}

class _PoiDetailScreenState extends State<PoiDetailScreen> {
  final MapOfflineService _mapOfflineService = MapOfflineService();
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _mapOfflineService.initialize();
    _detectUserPosition();
  }

  Future<void> _detectUserPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      // Ignore temporary location failures.
    }
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

  Color _getPoiColor(String type) {
    switch (type) {
      case 'viewpoint':
        return Colors.blue;
      case 'flora':
        return Colors.green;
      case 'fauna':
        return Colors.orange;
      case 'historical':
        return Colors.brown;
      case 'water':
        return Colors.cyan;
      case 'camping':
        return Colors.teal;
      case 'danger':
        return Colors.red;
      case 'rest_area':
        return Colors.purple;
      case 'information':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final poi = widget.poi;
    final poiColor = _getPoiColor(poi.type);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: EcoShortcutBadge(
        currentTab: EcoShortcutTab.map,
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
                  height: 280,
                  width: double.infinity,
                  child: poi.mediaUrl != null
                      ? CachedNetworkImage(
                          imageUrl: poi.mediaUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: Colors.grey[300]),
                          errorWidget: (_, __, ___) => Container(
                            color: poiColor.withValues(alpha: 0.2),
                            child: Icon(
                              _getPoiIcon(poi.type),
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Container(
                          color: poiColor.withValues(alpha: 0.2),
                          child: Icon(
                            _getPoiIcon(poi.type),
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                ),
                Container(
                  height: 280,
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
                  child: _CircleIconButton(
                    icon: Icons.arrow_back_ios_new,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: poiColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          poi.typeDisplayName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        poi.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                          height: 1.06,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
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
                      color: Theme.of(context).cardColor,
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
                            icon: _getPoiIcon(poi.type),
                            label: 'Type',
                            value: poi.typeDisplayName,
                            color: poiColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FactBox(
                            icon: Icons.location_on,
                            label: 'Coordonnees',
                            value:
                                '${poi.latitude.toStringAsFixed(4)}, ${poi.longitude.toStringAsFixed(4)}',
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'A propos du point',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    poi.description,
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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NavigationSosScreen(
                              destination: LatLng(poi.latitude, poi.longitude),
                              destinationLabel: poi.name,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.route),
                      label: const Text('Directions sur la carte'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Localisation',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 200,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(poi.latitude, poi.longitude),
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                            userAgentPackageName: 'com.ecoguide.app',
                            tileProvider: LocalFirstTileProvider(
                              service: _mapOfflineService,
                            ),
                          ),
                          if (_currentPosition != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [
                                    _currentPosition!,
                                    LatLng(poi.latitude, poi.longitude),
                                  ],
                                  strokeWidth: 4,
                                  color: Colors.green,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              if (_currentPosition != null)
                                Marker(
                                  point: _currentPosition!,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(7),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              Marker(
                                point: LatLng(poi.latitude, poi.longitude),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: poiColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    _getPoiIcon(poi.type),
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Coordonnees: ${poi.latitude.toStringAsFixed(6)}, ${poi.longitude.toStringAsFixed(6)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (_currentPosition != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Distance depuis votre position: ${const Distance().as(LengthUnit.Kilometer, _currentPosition!, LatLng(poi.latitude, poi.longitude)).toStringAsFixed(2)} km',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 24),

                  _buildPoiMediaSection(poi),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoiMediaSection(Poi poi) {
    final images = _poiImageUrls(poi);
    final videos = _poiVideoUrls(poi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty) ...[
          Text(
            'Galerie',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: images[index],
                    width: 148,
                    height: 112,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(width: 148, color: Colors.grey[300]),
                    errorWidget: (_, __, ___) => Container(
                      width: 148,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          'Video',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        if (videos.isNotEmpty)
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _MediaActionCard(
                  icon: Icons.play_circle_fill,
                  title: 'Video ${index + 1}',
                  subtitle: 'Ouvrir la video',
                  enabled: true,
                  onTap: () => _openMediaUrl(videos[index]),
                );
              },
            ),
          )
        else
          _MediaActionCard(
            icon: Icons.play_circle_outline,
            title: 'Video',
            subtitle: 'Aucune video disponible',
            enabled: false,
            onTap: null,
          ),
        const SizedBox(height: 24),
        Text(
          'Voix off',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        _MediaActionCard(
          icon: Icons.volume_up,
          title: 'Guide audio',
          subtitle: poi.audioGuideUrl != null && poi.audioGuideUrl!.isNotEmpty
              ? 'Ecouter la voix off'
              : 'Voix off non disponible',
          enabled: poi.audioGuideUrl != null && poi.audioGuideUrl!.isNotEmpty,
          onTap: poi.audioGuideUrl != null && poi.audioGuideUrl!.isNotEmpty
              ? () => _openMediaUrl(poi.audioGuideUrl!)
              : null,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<String> _poiImageUrls(Poi poi) {
    final urls = <String>[
      if (poi.mediaUrl != null && poi.mediaUrl!.isNotEmpty) poi.mediaUrl!,
      ...?poi.additionalMediaUrls,
    ];

    return urls.where((url) => !_isVideoUrl(url)).toSet().toList();
  }

  List<String> _poiVideoUrls(Poi poi) {
    final urls = <String>[
      ...?poi.videoUrls,
      ...?poi.additionalMediaUrls,
      if (poi.learnMoreUrl != null && _isVideoUrl(poi.learnMoreUrl!))
        poi.learnMoreUrl!,
    ];

    return urls.where(_isVideoUrl).toSet().toList();
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.contains('vimeo.com');
  }

  Future<void> _openMediaUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _MediaActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const _MediaActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppTheme.primaryColor : Colors.grey;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          color: Theme.of(context).cardColor.withValues(alpha: 0.92),
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
  final Color color;

  const _FactBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
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
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
