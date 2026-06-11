import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/map_tile_url.dart';
import '../../services/voice_service.dart';
import '../../core/widgets/eco_shortcut_badge.dart';
import '../../core/widgets/fullscreen_image_viewer.dart';
import '../../models/poi.dart';
import '../../providers/locale_provider.dart';
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
  final PageController _heroPageController = PageController();
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _tts = FlutterTts();
  LatLng? _currentPosition;
  bool _ttsPlaying = false;
  bool _heroCollapsed = false;
  bool _navigatingToDirections = false;
  int _heroImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _mapOfflineService.initialize();
    _detectUserPosition();
    _scrollController.addListener(() {
      final collapsed = _scrollController.offset > 260;
      if (collapsed != _heroCollapsed) setState(() => _heroCollapsed = collapsed);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _ttsPlaying = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _ttsPlaying = false);
    });
  }

  @override
  void dispose() {
    _heroPageController.dispose();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleVoiceOver() async {
    if (_ttsPlaying) {
      await _tts.stop();
      setState(() => _ttsPlaying = false);
      return;
    }
    // Respect the global voice setting (Paramètres → Lecture vocale).
    if (!VoiceService.instance.isEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                context.read<LocaleProvider>().t('voice.disabledHint'),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
      }
      return;
    }
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    await VoiceService.instance
        .configure(_tts, langTag: VoiceService.tag(langCode));
    final text = '${widget.poi.name}. ${widget.poi.description}';
    setState(() => _ttsPlaying = true);
    await _tts.speak(text);
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
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildPoiHero(poi, poiColor)),
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
                            label: context.watch<LocaleProvider>().t('poi.type'),
                            value: poi.typeDisplayName,
                            color: poiColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FactBox(
                            icon: Icons.location_on,
                            label: context.watch<LocaleProvider>().t('poi.coords'),
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
                    context.watch<LocaleProvider>().t('poi.about'),
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
                      onPressed: _navigatingToDirections
                          ? null
                          : () async {
                              setState(() => _navigatingToDirections = true);
                              try {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NavigationSosScreen(
                                      destination: LatLng(
                                          poi.latitude, poi.longitude),
                                      destinationLabel: poi.name,
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
                          : context.watch<LocaleProvider>().t('poi.directions')),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    context.watch<LocaleProvider>().t('poi.location'),
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
                            urlTemplate: mapTileUrlForTheme(context),
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
                    '${context.watch<LocaleProvider>().t('poi.coords')}: ${poi.latitude.toStringAsFixed(6)}, ${poi.longitude.toStringAsFixed(6)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (_currentPosition != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${context.watch<LocaleProvider>().t('poi.distance')}: ${const Distance().as(LengthUnit.Kilometer, _currentPosition!, LatLng(poi.latitude, poi.longitude)).toStringAsFixed(2)} km',
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
          // Sticky top bar — appears once hero scrolls out of view
          AnimatedSlide(
            offset: _heroCollapsed ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _heroCollapsed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  left: 4,
                  right: 4,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        poi.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoiHero(Poi poi, Color poiColor) {
    final images = _poiImageUrls(poi);

    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          // ── Swipeable image carousel ──────────────────────────────
          if (images.isEmpty)
            Container(
              color: poiColor.withValues(alpha: 0.2),
              child: Center(
                child: Icon(_getPoiIcon(poi.type), size: 64, color: Colors.white),
              ),
            )
          else
            PageView.builder(
              controller: _heroPageController,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _heroImageIndex = i),
              itemBuilder: (ctx, i) => GestureDetector(
                onTap: () => FullscreenImageViewer.open(context, images, i),
                child: CachedNetworkImage(
                  imageUrl: images[i],
                  fit: BoxFit.cover,
                  placeholder: (ctx, url) => Container(color: Colors.grey[300]),
                  errorWidget: (ctx, url, err) => Container(
                    color: poiColor.withValues(alpha: 0.2),
                    child: Icon(_getPoiIcon(poi.type), size: 64, color: Colors.white),
                  ),
                ),
              ),
            ),

          // ── Gradient ──────────────────────────────────────────────
          IgnorePointer(
            child: Container(
              height: 280,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xAA000000)],
                ),
              ),
            ),
          ),

          // ── Back button ───────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 14,
            child: _CircleIconButton(
              icon: Icons.arrow_back_ios_new,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // ── Dot indicators (multiple images) ──────────────────────
          if (images.length > 1)
            Positioned(
              bottom: 72,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _heroImageIndex ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _heroImageIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

          // ── Bottom info: type badge + name + voice-over ───────────
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                    if (images.length > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_outlined,
                                color: Colors.white, size: 11),
                            const SizedBox(width: 4),
                            Text(
                              '${_heroImageIndex + 1}/${images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        poi.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                          height: 1.06,
                          shadows: [
                            Shadow(color: Colors.black45, offset: Offset(0, 2), blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _toggleVoiceOver,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _ttsPlaying
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _ttsPlaying ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                          color: _ttsPlaying ? AppTheme.primaryColor : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoiMediaSection(Poi poi) {
    final videos = _poiVideoUrls(poi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.watch<LocaleProvider>().t('poi.video'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        if (videos.isNotEmpty)
          Column(
            children: videos.asMap().entries.map((e) {
              return Padding(
                padding: EdgeInsets.only(bottom: e.key < videos.length - 1 ? 12 : 0),
                child: _InlineVideoPlayer(url: e.value, index: e.key),
              );
            }).toList(),
          )
        else
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off_rounded,
                      size: 36,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text(
                    context.watch<LocaleProvider>().t('poi.noVideo'),
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // const SizedBox(height: 24),
        // Text(
        //   context.watch<LocaleProvider>().t('poi.voiceover'),
        //   style: TextStyle(
        //     fontSize: 24,
        //     fontWeight: FontWeight.w800,
        //     color: Theme.of(context).colorScheme.onSurface,
        //   ),
        // ),
        // const SizedBox(height: 8),
        // _MediaActionCard(
        //   icon: Icons.volume_up,
        //   title: context.watch<LocaleProvider>().t('poi.audioGuide'),
        //   subtitle: poi.audioGuideUrl != null && poi.audioGuideUrl!.isNotEmpty
        //       ? context.watch<LocaleProvider>().t('poi.audioGuide')
        //       : context.watch<LocaleProvider>().t('poi.noAudio'),
        //   enabled: poi.audioGuideUrl != null && poi.audioGuideUrl!.isNotEmpty,
        //   onTap: poi.audioGuideUrl != null && poi.audioGuideUrl!.isNotEmpty
        //       ? () => _openMediaUrl(poi.audioGuideUrl!)
        //       : null,
        // ),
        // const SizedBox(height: 24),
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

  // ignore: unused_element
  Future<void> _openMediaUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ignore: unused_element
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

class _InlineVideoPlayer extends StatefulWidget {
  final String url;
  final int index;

  const _InlineVideoPlayer({required this.url, required this.index});

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  // Direct video (mp4/webm/mov)
  VideoPlayerController? _vpController;
  ChewieController? _chewieController;

  // YouTube
  YoutubePlayerController? _ytController;

  bool _initialized = false;
  bool _error = false;
  bool _loading = false;

  bool get _isYoutube {
    final u = widget.url.toLowerCase();
    return u.contains('youtube.com') || u.contains('youtu.be');
  }

  String? get _youtubeId =>
      YoutubePlayer.convertUrlToId(widget.url);

  Future<void> _initPlayer() async {
    if (_loading || _initialized) return;
    setState(() => _loading = true);

    if (_isYoutube) {
      final id = _youtubeId;
      if (id == null) {
        setState(() { _error = true; _loading = false; });
        return;
      }
      final yt = YoutubePlayerController(
        initialVideoId: id,
        flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
      );
      if (!mounted) { yt.dispose(); return; }
      setState(() {
        _ytController = yt;
        _initialized = true;
        _loading = false;
      });
    } else {
      try {
        final vp = VideoPlayerController.networkUrl(Uri.parse(widget.url));
        await vp.initialize();
        final chewie = ChewieController(
          videoPlayerController: vp,
          autoPlay: true,
          looping: false,
          aspectRatio: vp.value.aspectRatio,
          placeholder: Container(color: Colors.black),
        );
        if (!mounted) { vp.dispose(); chewie.dispose(); return; }
        setState(() {
          _vpController = vp;
          _chewieController = chewie;
          _initialized = true;
          _loading = false;
        });
      } catch (_) {
        if (mounted) setState(() { _error = true; _loading = false; });
      }
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    _chewieController?.dispose();
    _vpController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_initialized && _ytController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: YoutubePlayer(
          controller: _ytController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: theme.colorScheme.primary,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 220,
        color: Colors.black,
        child: _initialized
            ? Chewie(controller: _chewieController!)
            : _error
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.white54, size: 36),
                        const SizedBox(height: 8),
                        const Text(
                          'Impossible de charger la vidéo',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: _initPlayer,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(color: Colors.black87),
                        if (_isYoutube && _youtubeId != null)
                          Image.network(
                            'https://img.youtube.com/vi/${_youtubeId!}/hqdefault.jpg',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (ctx, err, st) =>
                                Container(color: Colors.black87),
                          ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_loading)
                              const CircularProgressIndicator(color: Colors.white)
                            else ...[
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: _isYoutube
                                      ? Colors.red.withValues(alpha: 0.9)
                                      : theme.colorScheme.primary
                                          .withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 38),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _isYoutube
                                      ? 'YouTube — Appuyer pour lire'
                                      : 'Vidéo ${widget.index + 1} — Appuyer pour lire',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
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
