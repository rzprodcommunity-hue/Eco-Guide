import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import '../../core/widgets/error_banner.dart';
import '../../models/trail.dart';
import '../../models/trail_review.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/poi_provider.dart';
import '../../services/map_offline_service.dart';
import '../../services/review_service.dart';
import '../map/navigation_sos_screen.dart';
import '../offline/offline_trails_screen.dart';
import '../sos/sos_button.dart';
import '../poi/poi_detail_screen.dart';

class TrailDetailScreen extends StatefulWidget {
  final Trail trail;

  const TrailDetailScreen({super.key, required this.trail});

  @override
  State<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends State<TrailDetailScreen> {
  final MapOfflineService _mapOfflineService = MapOfflineService();
  List<TrailReview> _reviews = [];
  bool _reviewsLoading = true;

  @override
  void initState() {
    super.initState();
    _mapOfflineService.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoiProvider>().loadPoisByTrail(widget.trail.id);
      _loadReviews();
    });
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
                      _buildTrailGallery(),
                      const SizedBox(height: 32),
                      _buildTrailMapSection(),
                      const SizedBox(height: 32),
                      _buildElevationProfile(),
                      const SizedBox(height: 32),
                      _buildPoisSection(poiProvider),
                      const SizedBox(height: 32),
                      _buildReviewsSection(),
                      const SizedBox(height: 120), // Padding for bottom bar
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    return Stack(
      children: [
        SizedBox(
          height: 380,
          width: double.infinity,
          child:
              widget.trail.imageUrls != null &&
                  widget.trail.imageUrls!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: widget.trail.imageUrls!.first,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[300]),
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
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  const Icon(
                    Icons.location_on,
                    color: Colors.white70,
                    size: 14,
                  ),
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

  Widget _buildTrailGallery() {
    final images = widget.trail.imageUrls ?? const <String>[];
    if (images.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos du sentier',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: images[index],
                  width: 170,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(width: 170, color: Colors.grey[300]),
                  errorWidget: (_, __, ___) => Container(
                    width: 170,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              );
            },
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
            height: 180,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: startPoint,
                initialZoom: routePoints.length > 1 ? 13 : 14,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
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
                if (routePoints.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: 4,
                        color: Theme.of(context).primaryColor,
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
                          color: Theme.of(context).primaryColor,
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
            Text(
              "Max: 1,650m",
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
          child: CustomPaint(
            painter: _ElevationChartPainter(),
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
                      "2km",
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      "4km",
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      "6km",
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
              separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.navigation, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      context.watch<LocaleProvider>().t('trail.start'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              ),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SosScreen(),
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                child: const Center(
                  child: Text(
                    "SOS",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
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
          color: isFav ? const Color(0xFFE91E8C) : const Color(0xFF111111),
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
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2E7D32).withValues(alpha: 0.2),
          const Color(0xFF2E7D32).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final points = [
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.2, size.height * 0.65),
      Offset(size.width * 0.4, size.height * 0.55),
      Offset(size.width * 0.6, size.height * 0.45),
      Offset(size.width * 0.8, size.height * 0.5),
      Offset(size.width, size.height * 0.6),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i + 1];
      path.lineTo(p1.dx, p1.dy);
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    for (var point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
