import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import '../../core/utils/map_tile_url.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/fullscreen_image_viewer.dart';
import '../../models/trail.dart';
import '../../models/trail_review.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/poi_provider.dart';
import '../../services/map_offline_service.dart';
import '../../services/review_service.dart';
import '../../services/trail_unlock_service.dart';
import '../map/navigation_sos_screen.dart';
import '../offline/offline_trails_screen.dart';
import '../poi/poi_detail_screen.dart';
import '../settings/qr_unlock_screen.dart';
import '../sos/sos_button.dart';

class TrailDetailScreen extends StatefulWidget {
  final Trail trail;

  const TrailDetailScreen({super.key, required this.trail});

  @override
  State<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends State<TrailDetailScreen> {
  final MapOfflineService _mapOfflineService = MapOfflineService();
  final PageController _heroPageController = PageController();
  final ScrollController _scrollController = ScrollController();
  final MapController _trailMapController = MapController();
  int _heroImageIndex = 0;
  bool _heroCollapsed = false;
  List<TrailReview> _reviews = [];
  bool _reviewsLoading = true;
  bool _trailUnlocked = false;
  Duration? _unlockRemaining;

  // Real terrain-elevation profile sampled along the trail path (computed via
  // the Open-Meteo elevation API since the GeoJSON only carries 2D points).
  List<double>? _elevations;
  bool _loadingElevation = false;
  bool _elevationFailed = false;

  @override
  void initState() {
    super.initState();
    _mapOfflineService.initialize();
    _checkUnlock();
    _scrollController.addListener(() {
      final collapsed = _scrollController.offset > 300;
      if (collapsed != _heroCollapsed) setState(() => _heroCollapsed = collapsed);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoiProvider>().loadPoisByTrail(widget.trail.id);
      _loadReviews();
      _loadElevationProfile();
    });
  }

  @override
  void dispose() {
    _heroPageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _reviewsLoading = true);
    try {
      final reviews = await ReviewService.getReviews(widget.trail.id);
      if (mounted) setState(() => _reviews = reviews);
    } catch (_) {
      if (mounted) setState(() => _reviews = []);
    } finally {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _checkUnlock() async {
    final unlocked = await TrailUnlockService.instance.isUnlocked(
      trailId: widget.trail.id,
      trailName: widget.trail.name,
    );
    final remaining = unlocked
        ? await TrailUnlockService.instance.remaining(
            trailId: widget.trail.id,
            trailName: widget.trail.name,
          )
        : null;
    if (mounted) {
      setState(() {
        _trailUnlocked = unlocked;
        _unlockRemaining = remaining;
      });
    }
  }

  /// Shown when the user taps "Démarrer" on a trail that has not been unlocked
  /// by scanning the guide's QR code.
  Future<void> _showLockedDialog() async {
    final goScan = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock, color: Color(0xFFD54A3A), size: 40),
        title: const Text('Sentier verrouillé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ce sentier doit être ouvert par un guide. Scannez le QR code '
              'fourni, ou contactez l\'administrateur pour l\'ouvrir.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD54A3A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Code d\'erreur : ${TrailUnlockService.lockedErrorCode}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD54A3A),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Scanner le QR'),
          ),
        ],
      ),
    );

    if (goScan == true && mounted) {
      final unlocked = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const QrUnlockScreen()),
      );
      if (unlocked == true) {
        await _checkUnlock();
        if (mounted) _startNavigation();
      }
    }
  }

  String _formatRemaining(Duration d) {
    if (d.inHours >= 1) return '${d.inHours} h restantes';
    if (d.inMinutes >= 1) return '${d.inMinutes} min restantes';
    return 'expire bientôt';
  }

  void _startNavigation() {
    if (widget.trail.startLatitude == null ||
        widget.trail.startLongitude == null) {
      return;
    }
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
  }

  String _getDifficultyText(String difficulty) {
    final lp = context.read<LocaleProvider>();
    switch (difficulty) {
      case 'easy':
        return lp.t('trails.easy');
      case 'moderate':
        return lp.t('trails.moderate');
      case 'difficult':
        return lp.t('trails.difficult');
      default:
        return difficulty;
    }
  }

  Future<void> _openAddCommentSheet() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final messenger = ScaffoldMessenger.of(context);

    final result = await showModalBottomSheet<_CommentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddCommentSheet(),
    );

    if (result == null || !mounted) return;

    try {
      final review = await ReviewService.addReview(
        trailId: widget.trail.id,
        userId: user.id,
        userName: user.fullName,
        userAvatar: user.avatarUrl,
        rating: result.rating,
        text: result.text,
      );
      if (mounted) {
        setState(() => _reviews.insert(0, review));
        messenger.showSnackBar(
          const SnackBar(content: Text('Commentaire publié !')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final poiProvider = context.watch<PoiProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildHeroImage()),
              if (poiProvider.error != null && poiProvider.error!.isNotEmpty)
                SliverToBoxAdapter(
                  child: ErrorBanner(
                    message: poiProvider.error!,
                    onRetry: () => poiProvider.loadPoisByTrail(widget.trail.id),
                    onDismiss: poiProvider.clearError,
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildStatsCard(),
                      const SizedBox(height: 32),
                      _buildAboutSection(),
                      const SizedBox(height: 32),
                      _buildTrailMapSection(),
                      const SizedBox(height: 32),
                      _buildElevationProfile(),
                      const SizedBox(height: 32),
                      _buildPoisSection(poiProvider),
                      const SizedBox(height: 32),
                      _buildReviewsSection(),
                      const SizedBox(height: 120),
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
                        widget.trail.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OfflineTrailsScreen(),
                        ),
                      ),
                    ),
                    _DetailFavoriteButton(trail: widget.trail),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    final images = widget.trail.imageUrls ?? [];

    return SizedBox(
      height: 380,
      child: Stack(
        children: [
          // ── Swipeable image carousel ──────────────────────────────────
          if (images.isEmpty)
            Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.landscape, size: 64, color: Colors.white),
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
                    color: Colors.grey[300],
                    child: const Icon(Icons.landscape, size: 64),
                  ),
                ),
              ),
            ),

          // ── Dark gradient ─────────────────────────────────────────────
          IgnorePointer(
            child: Container(
              height: 380,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
          ),

          // ── Top bar: back + download + favourite ──────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleIconButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).pop(),
                ),
                Row(
                  children: [
                    _CircleIconButton(
                      icon: Icons.download_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OfflineTrailsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _DetailFavoriteButton(trail: widget.trail),
                  ],
                ),
              ],
            ),
          ),

          // ── Dot indicators (multiple images) ──────────────────────────
          if (images.length > 1)
            Positioned(
              bottom: 100,
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

          // ── Bottom info ───────────────────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getDifficultyText(widget.trail.difficulty).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (images.length > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 12,
                            ),
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
                Text(
                  widget.trail.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      widget.trail.region ?? 'Région inconnue',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.star, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.trail.averageRating?.toStringAsFixed(1) ?? '4.8'} (${widget.trail.reviewCount ?? 240} ${context.watch<LocaleProvider>().t('trail.reviewsCount')})',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.route_outlined,
            context.watch<LocaleProvider>().t('trail.distance'),
            widget.trail.distanceText,
          ),
          _buildStatItem(
            Icons.access_time,
            context.watch<LocaleProvider>().t('trail.duration'),
            widget.trail.durationText,
          ),
          _buildStatItem(
            Icons.terrain,
            context.watch<LocaleProvider>().t('trail.elevation'),
            widget.trail.elevationGain != null
                ? '+${widget.trail.elevationGain!.toInt()} m'
                : '+450 m',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.2)
                : Theme.of(context).primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                  : Theme.of(context).primaryColor.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(
            icon,
            color: isDark
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).primaryColor,
            size: 26,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.watch<LocaleProvider>().t('trail.about'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.trail.description,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildTrailMapSection() {
    final routePoints = _trailRoutePoints();
    final startPoint =
        widget.trail.startLatitude != null &&
            widget.trail.startLongitude != null
        ? LatLng(widget.trail.startLatitude!, widget.trail.startLongitude!)
        : routePoints.isNotEmpty
        ? routePoints.first
        : null;

    if (startPoint == null) return const SizedBox.shrink();

    final endPoint = routePoints.length > 1 ? routePoints.last : null;

    final allPoints = <LatLng>[
      startPoint,
      ...routePoints,
      ?endPoint,
    ];

    final bounds = allPoints.length > 1
        ? LatLngBounds.fromPoints(allPoints)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Carte du sentier',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _trailMapController,
                  options: MapOptions(
                    initialCenter: startPoint,
                    initialZoom: 14,
                    minZoom: 3,
                    maxZoom: 18,
                    initialCameraFit: bounds != null
                        ? CameraFit.bounds(
                            bounds: bounds,
                            padding: const EdgeInsets.all(40),
                          )
                        : null,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.doubleTapZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: mapTileUrlForTheme(context),
                      userAgentPackageName: 'com.ecoguide.app',
                      maxZoom: 18,
                      maxNativeZoom: 18,
                      tileProvider: LocalFirstTileProvider(
                        service: _mapOfflineService,
                      ),
                    ),
                    if (routePoints.length > 1)
                      PolylineLayer(
                        polylines: [
                          // White casing underneath for contrast over the map.
                          Polyline(
                            points: routePoints,
                            strokeWidth: 7,
                            color: Colors.white,
                          ),
                          // Yellow-orange trail line.
                          Polyline(
                            points: routePoints,
                            strokeWidth: 4.5,
                            color: const Color(0xFFF5A623),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: startPoint,
                          width: 38,
                          height: 38,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E7A23),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.hiking,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        if (endPoint != null)
                          Marker(
                            point: endPoint,
                            width: 38,
                            height: 38,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFD32F2F),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.flag,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Column(
                    children: [
                      _buildMapZoomButton(
                        icon: Icons.add,
                        onTap: () {
                          final next = (_trailMapController.camera.zoom + 1)
                              .clamp(3.0, 18.0);
                          _trailMapController.move(
                            _trailMapController.camera.center,
                            next,
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      _buildMapZoomButton(
                        icon: Icons.remove,
                        onTap: () {
                          final next = (_trailMapController.camera.zoom - 1)
                              .clamp(3.0, 18.0);
                          _trailMapController.move(
                            _trailMapController.camera.center,
                            next,
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      _buildMapZoomButton(
                        icon: Icons.fit_screen,
                        onTap: () {
                          if (bounds == null) return;
                          _trailMapController.fitCamera(
                            CameraFit.bounds(
                              bounds: bounds,
                              padding: const EdgeInsets.all(40),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapZoomButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  List<LatLng> _trailRoutePoints() {
    final points = <LatLng>[];
    final geojson = widget.trail.geojson;
    if (geojson == null) return points;

    try {
      final features = geojson['features'] as List?;
      if (features == null || features.isEmpty) return points;

      final geometry = features.first['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List?;
      if (geometry?['type'] != 'LineString' || coordinates == null) {
        return points;
      }

      for (final coord in coordinates) {
        if (coord is List && coord.length >= 2) {
          points.add(
            LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble()),
          );
        }
      }
    } catch (_) {
      return const [];
    }

    return points;
  }

  Widget _buildElevationProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "Profil d'altitude",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (_elevations != null && _elevations!.isNotEmpty)
              Text(
                "Max: ${_elevations!.reduce((a, b) => a > b ? a : b).round()} m",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 160,
          width: double.infinity,
          padding: const EdgeInsets.only(
            top: 24,
            bottom: 8,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
            ),
          ),
          child: (_elevations == null || _elevations!.length < 2)
              ? Center(
                  child: _loadingElevation
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _elevationFailed
                              ? 'Profil indisponible hors ligne'
                              : 'Profil indisponible',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                )
              : CustomPaint(
            painter: _ElevationChartPainter(
              _elevations!,
              Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Départ",
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '${(widget.trail.distance * 0.25).toStringAsFixed(1)}km',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '${(widget.trail.distance * 0.5).toStringAsFixed(1)}km',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '${(widget.trail.distance * 0.75).toStringAsFixed(1)}km',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      "Arrivée",
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the real elevation profile by sampling the trail path and asking
  /// the free Open-Meteo elevation API for the terrain altitude at each point.
  Future<void> _loadElevationProfile() async {
    final coords = _trailPathCoords();
    if (coords.length < 2) return; // no path → nothing to profile
    setState(() => _loadingElevation = true);
    try {
      final sampled = _sampleCoords(coords, 60);
      final lats = sampled.map((c) => c.latitude.toStringAsFixed(5)).join(',');
      final lons = sampled.map((c) => c.longitude.toStringAsFixed(5)).join(',');
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/elevation?latitude=$lats&longitude=$lons',
      );
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['elevation'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList();
        if (list != null && list.length >= 2 && mounted) {
          setState(() {
            _elevations = list;
            _loadingElevation = false;
          });
          return;
        }
      }
      if (mounted) {
        setState(() {
          _elevationFailed = true;
          _loadingElevation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _elevationFailed = true;
          _loadingElevation = false;
        });
      }
    }
  }

  /// Extracts the trail's LineString coordinates ([lng,lat] → LatLng).
  List<LatLng> _trailPathCoords() {
    final geo = widget.trail.geojson;
    if (geo == null) return [];
    try {
      final features = geo['features'] as List?;
      if (features == null || features.isEmpty) return [];
      final geometry = features[0]['geometry'] as Map<String, dynamic>;
      if (geometry['type'] != 'LineString') return [];
      final coords = geometry['coordinates'] as List;
      return coords
          .map((c) =>
              LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Evenly samples at most [maxPoints] points (Open-Meteo allows up to 100).
  List<LatLng> _sampleCoords(List<LatLng> pts, int maxPoints) {
    if (pts.length <= maxPoints) return pts;
    final out = <LatLng>[];
    final step = pts.length / maxPoints;
    for (double i = 0; i < pts.length; i += step) {
      out.add(pts[i.floor()]);
    }
    if (out.isEmpty || out.last != pts.last) out.add(pts.last);
    return out;
  }

  Widget _buildPoisSection(PoiProvider poiProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "Points d'intérêt",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              "${poiProvider.pois.length} lieux",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (poiProvider.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (poiProvider.pois.isEmpty)
          Text(
            "Aucun point d'intérêt",
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          )
        else
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: poiProvider.pois.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final poi = poiProvider.pois[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PoiDetailScreen(poi: poi),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 160,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: SizedBox(
                            height: 100,
                            width: double.infinity,
                            child:
                                poi.mediaUrl != null && poi.mediaUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: poi.mediaUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: Colors.grey[300],
                                    child: Icon(_getPoiIcon(poi.type)),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                poi.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.eco,
                                    size: 12,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      poi.badge ?? poi.typeDisplayName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildLegacyReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "Avis de la communauté",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              "Voir tout",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildReviewCard(
          "ML",
          "Marc L.",
          "il y a 2 jours",
          "5.0",
          "Sentier très bien balisé. La montée finale est un peu raide mais la vue en vaut vraiment la peine ! Prévoyez de bonnes chaussures.",
        ),
        const SizedBox(height: 12),
        _buildReviewCard(
          "SG",
          "Sophie G.",
          "il y a 1 semaine",
          "4.5",
          "Magnifique en cette saison. Attention, certains passages sont glissants s'il a plu la veille. Les bâtons sont recommandés.",
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Avis de la communaute',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Voir tout',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _openAddCommentSheet,
          icon: const Icon(Icons.rate_review_outlined),
          label: const Text('Commenter'),
        ),
        const SizedBox(height: 16),
        if (_reviewsLoading)
          const Center(child: CircularProgressIndicator())
        else if (_reviews.isEmpty)
          Center(
            child: Text(
              context.watch<LocaleProvider>().t('trail.noReviewsYet'),
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          )
        else
          ..._reviews.asMap().entries.map((entry) {
            final review = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == _reviews.length - 1 ? 0 : 12,
              ),
              child: _buildReviewCard(
                review.initials,
                review.userName,
                review.timeAgo,
                review.rating.toStringAsFixed(1),
                review.text,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildReviewCard(
    String initials,
    String name,
    String date,
    String rating,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF5D4037),
                    radius: 18,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      rating,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom > 0
              ? MediaQuery.of(context).padding.bottom
              : 16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed:
                    widget.trail.startLatitude == null ||
                        widget.trail.startLongitude == null
                    ? null
                    : () {
                        if (_trailUnlocked) {
                          _startNavigation();
                        } else {
                          _showLockedDialog();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _trailUnlocked
                      ? Theme.of(context).primaryColor
                      : const Color(0xFF8A8A8A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _trailUnlocked ? Icons.navigation : Icons.lock,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _trailUnlocked
                            ? (_unlockRemaining != null
                                ? '${context.watch<LocaleProvider>().t('trail.start')} · ${_formatRemaining(_unlockRemaining!)}'
                                : context.watch<LocaleProvider>().t('trail.start'))
                            : 'Verrouillé — scanner le QR',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            const _TrailSosButton(),
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

class _DetailFavoriteButton extends StatelessWidget {
  final Trail trail;

  const _DetailFavoriteButton({required this.trail});

  @override
  Widget build(BuildContext context) {
    final favProvider = context.watch<FavoritesProvider>();
    final isFav = favProvider.isFavorite(trail.id);

    return GestureDetector(
      onTap: () => favProvider.toggle(trail),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: isFav ? const Color(0xFFE53935) : const Color(0xFF111111),
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF111111)),
      ),
    );
  }
}

class _ElevationChartPainter extends CustomPainter {
  /// Terrain altitudes (metres) sampled from start to finish along the path.
  final List<double> elevations;
  final Color color;

  _ElevationChartPainter(this.elevations, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (elevations.length < 2) return;

    double minE = elevations.first;
    double maxE = elevations.first;
    for (final e in elevations) {
      if (e < minE) minE = e;
      if (e > maxE) maxE = e;
    }
    // Avoid a divide-by-zero on a perfectly flat trail.
    final range = (maxE - minE) < 1 ? 1.0 : (maxE - minE);

    // Keep the curve off the very top/bottom edges.
    final topPad = size.height * 0.12;
    final usable = size.height * 0.74;

    Offset pointAt(int i) {
      final x = size.width * (i / (elevations.length - 1));
      final norm = (elevations[i] - minE) / range; // 0 = lowest, 1 = highest
      final y = topPad + usable * (1 - norm);
      return Offset(x, y);
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.22),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (int i = 1; i < elevations.length; i++) {
      final p = pointAt(i);
      path.lineTo(p.dx, p.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _ElevationChartPainter oldDelegate) =>
      oldDelegate.elevations != elevations || oldDelegate.color != color;
}

class _CommentResult {
  final double rating;
  final String text;
  const _CommentResult({required this.rating, required this.text});
}

class _AddCommentSheet extends StatefulWidget {
  const _AddCommentSheet();

  @override
  State<_AddCommentSheet> createState() => _AddCommentSheetState();
}

class _AddCommentSheetState extends State<_AddCommentSheet> {
  final TextEditingController _controller = TextEditingController();
  double _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez un commentaire avant d\'envoyer.')),
      );
      return;
    }
    setState(() => _submitting = true);
    Navigator.of(context).pop(_CommentResult(rating: _rating, text: text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final accent = theme.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.rate_review_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Votre avis compte',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: onSurface,
                            ),
                          ),
                          Text(
                            'Partagez votre expérience',
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded,
                          color: onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _ratingLabel(_rating),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final v = (i + 1).toDouble();
                          final filled = v <= _rating;
                          return GestureDetector(
                            onTap: () => setState(() => _rating = v),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 38,
                                color: filled
                                    ? const Color(0xFFFFB400)
                                    : onSurface.withValues(alpha: 0.25),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: 500,
                    style: TextStyle(color: onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Décrivez votre randonnée, les paysages, les difficultés...',
                      hintStyle: TextStyle(
                        color: onSurface.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                      counterStyle: TextStyle(
                        color: onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Publier mon commentaire',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _ratingLabel(double r) {
    if (r >= 5) return 'Excellent !';
    if (r >= 4) return 'Très bien';
    if (r >= 3) return 'Correct';
    if (r >= 2) return 'Décevant';
    return 'À éviter';
  }
}

/// Compact SOS button reproducing the main SOS screen design:
/// pulsing halo + three nested radial-gradient shells. Opens [SosScreen].
class _TrailSosButton extends StatefulWidget {
  const _TrailSosButton();

  @override
  State<_TrailSosButton> createState() => _TrailSosButtonState();
}

class _TrailSosButtonState extends State<_TrailSosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openSos() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SosScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openSos,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final t = _pulseController.value; // 0 → 1 → 0
          return SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Halo 1 — outer ──────────────────────────────────────
                Transform.scale(
                  scale: 1.0 + t * 0.18,
                  child: Opacity(
                    opacity: (0.85 - t * 0.50).clamp(0.0, 1.0),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE53935).withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                ),
                // ── Halo 2 — inner ──────────────────────────────────────
                Transform.scale(
                  scale: 1.0 + t * 0.10,
                  child: Opacity(
                    opacity: (0.80 - t * 0.35).clamp(0.0, 1.0),
                    child: Container(
                      width: 51,
                      height: 51,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE53935).withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                ),
                // ── Outer shell — animated glow ─────────────────────────
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(0, -0.36),
                      radius: 0.75,
                      colors: [
                        Color(0xFFFF7065),
                        Color(0xFFE53935),
                        Color(0xFFBD2723),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935)
                            .withValues(alpha: 0.30 + t * 0.22),
                        blurRadius: 10 + t * 10,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    // ── Middle shell ────────────────────────────────────
                    child: Container(
                      width: 49,
                      height: 49,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(0, -0.30),
                          radius: 0.65,
                          colors: [
                            Color(0xFFC42924),
                            Color(0xFFC62828),
                            Color(0xFFBC2724),
                          ],
                          stops: [0.0, 0.70, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Center(
                        // ── Inner face ──────────────────────────────────
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(0, -0.40),
                              radius: 0.65,
                              colors: [
                                Color(0xFFFF8C81),
                                Color(0xFFEF4945),
                                Color(0xFFC62828),
                              ],
                              stops: [0.0, 0.40, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                height: 1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    blurRadius: 0,
                                    offset: Offset(0, 1),
                                  ),
                                  Shadow(color: Colors.black26, blurRadius: 8),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
