import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/services/network_service.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/locale_provider.dart';
import '../../services/map_offline_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/poi.dart';
import '../../models/trail.dart';
import '../../providers/auth_provider.dart';
import '../../providers/poi_provider.dart';
import '../../providers/trail_provider.dart';
import '../../providers/weather_provider.dart';
import '../poi/poi_detail_screen.dart';
import '../trails/trail_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToTrails;
  final VoidCallback? onNavigateToOffline;
  final VoidCallback? onNavigateToQuiz;
  final VoidCallback? onNavigateToSos;
  final VoidCallback? onNavigateToPois;

  const DashboardScreen({
    super.key,
    this.onNavigateToMap,
    this.onNavigateToTrails,
    this.onNavigateToOffline,
    this.onNavigateToQuiz,
    this.onNavigateToSos,
    this.onNavigateToPois,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MapController _mapController = MapController();
  final MapOfflineService _mapOfflineService = MapOfflineService();
  _DashboardMapStyle _mapStyle = _DashboardMapStyle.standard;
  bool _hasCenteredOnUser = false;
  LatLng _currentPosition = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _mapOfflineService.initialize();
      _detectUserPosition();
    });
  }

  @override
  void dispose() {
    // Stop weather auto-refresh when leaving dashboard
    // (safe to call even if never started)
    try {
      context.read<WeatherProvider>().stopAutoRefresh();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadData() async {
    final trailProvider = context.read<TrailProvider>();
    final poiProvider = context.read<PoiProvider>();
    final weatherProvider = context.read<WeatherProvider>();
    final isOnline = await NetworkService.hasInternetConnection();
    if (!mounted) return;

    await Future.wait([
      trailProvider.loadTrails(refresh: true, forceOffline: !isOnline),
      poiProvider.loadPois(forceOffline: !isOnline),
    ]);

    if (isOnline) {
      await weatherProvider.loadCurrentWeather(
        lat: _currentPosition.latitude,
        lng: _currentPosition.longitude,
      );
    } else {
      weatherProvider.stopAutoRefresh();
      weatherProvider.clearError();
    }

    if (isOnline) {
      weatherProvider.startAutoRefresh(
        lat: _currentPosition.latitude,
        lng: _currentPosition.longitude,
      );
    }
  }

  Future<void> _refreshDashboard() async {
    final isOnline = await NetworkService.hasInternetConnection();
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isOnline
              ? 'Donnees rechargees depuis Supabase.'
              : 'Mode hors ligne: donnees rechargees depuis SQL.',
        ),
      ),
    );
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
      if (!_hasCenteredOnUser) {
        _mapController.move(_currentPosition, 14);
        _hasCenteredOnUser = true;
      }
      final isOnline = await NetworkService.hasInternetConnection();
      if (!mounted || !isOnline) return;
      context.read<WeatherProvider>().loadCurrentWeather(
        lat: position.latitude,
        lng: position.longitude,
      );
      context.read<WeatherProvider>().startAutoRefresh(
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (_) {}
  }

  String _getUserInitials(String? firstName, String? lastName, String email) {
    if (firstName != null && lastName != null) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    if (firstName != null) return firstName[0].toUpperCase();
    if (lastName != null) return lastName[0].toUpperCase();
    return email[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final trailProvider = context.watch<TrailProvider>();
    final poiProvider = context.watch<PoiProvider>();
    final weatherProvider = context.watch<WeatherProvider>();
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // appBar: const EcoPageHeader(
      //   title: 'Dashboard',
      //   showBackButton: false,
      //   showAccountBadge: false,
      // ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(user),
                  const SizedBox(height: 16),
                  _buildMapSection(),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  _buildNearbyTrails(trailProvider),
                  const SizedBox(height: 24),
                  _buildCurrentConditions(weatherProvider),
                  const SizedBox(height: 24),
                  _buildDiscoverNature(poiProvider),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            _buildStartTrekButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(dynamic user) {
    final firstName = user?.firstName ?? 'Explorateur';
    final lastName = user?.lastName;
    final email = user?.email ?? '';
    final displayName = lastName != null ? '$firstName $lastName' : firstName;
    final initials = _getUserInitials(
      user?.firstName,
      user?.lastName,
      email.isNotEmpty ? email : 'U',
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.watch<LocaleProvider>().t('home.welcomeBack'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _refreshDashboard,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualiser',
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2E7D32), width: 2),
                ),
                child: ClipOval(
                  child: user?.avatarUrl != null && (user!.avatarUrl as String).isNotEmpty
                      ? Image.network(
                          user.avatarUrl as String,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => Center(
                            child: Text(
                              initials,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentPosition,
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    key: ValueKey(_mapStyle),
                    urlTemplate: _mapStyle.urlTemplate,
                    userAgentPackageName: 'com.ecoguide.app',
                    tileProvider: LocalFirstTileProvider(
                      service: _mapOfflineService,
                    ),
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentPosition,
                        width: 24,
                        height: 24,
                        child: GestureDetector(
                          onTap: () =>
                              _mapController.move(_currentPosition, 15),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).cardColor,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Action Buttons
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).cardColor.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _mapStyle.icon,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _mapStyle.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        _buildMapButton(
                          icon: Icons.layers_outlined,
                          onTap: _cycleMapStyle,
                          bgColor: Theme.of(context).cardColor,
                        ),
                        const SizedBox(height: 8),
                        _buildMapButton(
                          icon: Icons.my_location,
                          onTap: () {
                            _mapController.move(_currentPosition, 14);
                          },
                          bgColor: const Color(0xFF2E7D32),
                          iconColor: Theme.of(context).cardColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Location Label
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.9)
                        : Theme.of(context).cardColor.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3)
                          : Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Jbel Chitana',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
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
    );
  }

  void _cycleMapStyle() {
    final styles = _DashboardMapStyle.values;
    final currentIndex = styles.indexOf(_mapStyle);
    final nextIndex = (currentIndex + 1) % styles.length;
    final nextStyle = styles[nextIndex];

    setState(() => _mapStyle = nextStyle);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(nextStyle.icon, color: Theme.of(context).cardColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mode carte active : ${nextStyle.label}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? bgColor,
    Color? iconColor,
  }) {
    final effectiveBgColor = bgColor ?? Theme.of(context).cardColor;
    final effectiveIconColor =
        iconColor ?? Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: effectiveBgColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: effectiveIconColor),
      ),
    );
  }

  Widget _buildQuickActions() {
    final lp = context.watch<LocaleProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildQuickActionItem(
            icon: Icons.landscape,
            label: lp.t('home.trails'),
            onTap: widget.onNavigateToTrails,
          ),
          _buildQuickActionItem(
            icon: Icons.map,
            label: lp.t('home.offline'),
            onTap: widget.onNavigateToOffline,
          ),
          _buildQuickActionItem(
            icon: Icons.eco,
            label: lp.t('home.ecoguide'),
            onTap: widget.onNavigateToQuiz,
          ),
          _buildQuickActionItem(
            icon: Icons.sos,
            label: lp.t('home.emergency'),
            onTap: widget.onNavigateToSos,
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyPois(PoiProvider poiProvider) {
    final pois = poiProvider.pois.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nearby POI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              GestureDetector(
                onTap: widget.onNavigateToPois,
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: poiProvider.isLoading && pois.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : pois.isEmpty
              ? const Center(child: Text('No POI available'))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: pois.length,
                  itemBuilder: (context, index) {
                    final poi = pois[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index < pois.length - 1 ? 12 : 0,
                      ),
                      child: _buildPoiCard(poi, _currentPosition),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPoiCard(Poi poi, LatLng currentPosition) {
    final hasImage = poi.mediaUrl != null && poi.mediaUrl!.isNotEmpty;
    final distanceKm = const Distance().as(
      LengthUnit.Kilometer,
      currentPosition,
      LatLng(poi.latitude, poi.longitude),
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PoiDetailScreen(poi: poi)),
        );
      },
      child: Container(
        width: 230,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: hasImage
                    ? Image.network(
                        poi.mediaUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              color: AppTheme.primaryColor,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPoiImagePlaceholder(),
                      )
                    : _buildPoiImagePlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poi.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    poi.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Theme.of(context).textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.7) ??
                          Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          poi.typeDisplayName,
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.near_me,
                        size: 13,
                        color:
                            Theme.of(context).textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.7) ??
                            Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${distanceKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.8) ??
                              Colors.grey,
                          fontWeight: FontWeight.w600,
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
  }

  Widget _buildPoiImagePlaceholder() {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.place,
          size: 30,
          color: AppTheme.primaryColor.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2)
                    : Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyTrails(TrailProvider trailProvider) {
    final trails = trailProvider.trails.take(5).toList();
    final lp = context.watch<LocaleProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lp.t('home.nearby'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              GestureDetector(
                onTap: widget.onNavigateToTrails,
                child: Text(
                  lp.t('home.seeAll'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: trailProvider.isLoading && trails.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : trails.isEmpty
              ? const Center(child: Text('No trails available'))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: trails.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index < trails.length - 1 ? 16 : 0,
                      ),
                      child: _buildTrailCard(trails[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTrailCard(Trail trail) {
    final hasImage = trail.imageUrls != null && trail.imageUrls!.isNotEmpty;
    final imageUrl = hasImage ? trail.imageUrls!.first : null;
    final difficulty = trail.difficulty.toLowerCase();
    final isEasy = difficulty == 'easy' || difficulty == 'facile';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TrailDetailScreen(trail: trail)),
        );
      },
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: hasImage
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: AppTheme.primaryColor,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholderImage(),
                          )
                        : _buildPlaceholderImage(),
                  ),
                ),
                // Rating badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Color(0xFFFFB800),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '4.8',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Difficulty badge
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isEasy
                          ? const Color(0xFF388E3C)
                          : const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isEasy ? 'Easy' : 'Hard',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trail.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: 15,
                        color:
                            Theme.of(context).textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.8) ??
                            Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trail.distanceText,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.8) ??
                              Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.timer_outlined,
                        size: 15,
                        color:
                            Theme.of(context).textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.8) ??
                            Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trail.durationText,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.8) ??
                              Colors.grey,
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
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            AppTheme.primaryColor.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.terrain,
              size: 36,
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              'No photo',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns dynamic gradient colors based on the current weather condition.
  List<Color> _weatherGradient(String condition, bool isDay) {
    if (!isDay) {
      return [const Color(0xFF1A237E), const Color(0xFF283593)];
    }
    switch (condition) {
      case 'Clear':
        return [const Color(0xFF42A5F5), const Color(0xFF1E88E5)];
      case 'Partly cloudy':
        return [const Color(0xFF4FC3F7), const Color(0xFF29B6F6)];
      case 'Rain':
      case 'Drizzle':
        return [const Color(0xFF546E7A), const Color(0xFF37474F)];
      case 'Thunderstorm':
        return [const Color(0xFF37474F), const Color(0xFF263238)];
      case 'Snow':
        return [const Color(0xFF90A4AE), const Color(0xFF78909C)];
      case 'Fog':
        return [const Color(0xFFB0BEC5), const Color(0xFF90A4AE)];
      default:
        return [const Color(0xFF4FC3F7), const Color(0xFF29B6F6)];
    }
  }

  String _lastUpdatedText(DateTime? lastFetch) {
    if (lastFetch == null) return '';
    final diff = DateTime.now().difference(lastFetch);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
    return 'Updated ${diff.inHours}h ago';
  }

  Widget _buildCurrentConditions(WeatherProvider weatherProvider) {
    final weather = weatherProvider.currentWeather;
    final isLoading = weatherProvider.isLoading && weather == null;

    final temperature = weather?.temperatureText ?? '22°C';
    final wind = weather?.windText ?? '12km/h';
    final humidity = weather?.humidityText ?? '45%';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.watch<LocaleProvider>().t('home.currentConditions'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        size: 36,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        temperature,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.air,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${context.watch<LocaleProvider>().t('home.wind')}: $wind',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.water_drop_outlined,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${context.watch<LocaleProvider>().t('home.humidity')}: $humidity',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.watch<LocaleProvider>().t('home.perfectHiking'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverNature(PoiProvider poiProvider) {
    final pois = poiProvider.pois.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.watch<LocaleProvider>().t('home.discover'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              GestureDetector(
                onTap: widget.onNavigateToPois,
                child: Text(
                  context.watch<LocaleProvider>().t('home.seeAll'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (poiProvider.isLoading && pois.isEmpty)
          const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (pois.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 100,
              child: Center(child: Text('No POI available')),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: List.generate(
                pois.length,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: index < pois.length - 1 ? 12 : 0,
                  ),
                  child: _buildDiscoverNatureCard(pois[index]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDiscoverNatureCard(Poi poi) {
    final hasImage = poi.mediaUrl != null && poi.mediaUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PoiDetailScreen(poi: poi)),
        );
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFF6EBE1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: hasImage
                    ? Image.network(
                        poi.mediaUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPoiImagePlaceholder(),
                      )
                    : _buildPoiImagePlaceholder(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      poi.typeDisplayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      poi.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      poi.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartTrekButton() {
    return Positioned(
      right: 20,
      bottom: 20,
      child: FloatingActionButton.extended(
        heroTag: 'startTrekDashboard',
        onPressed: widget.onNavigateToTrails,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).primaryColor.withValues(alpha: 0.9),
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: Text(
          context.watch<LocaleProvider>().t('home.startTrek'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

enum _DashboardMapStyle {
  standard(
    'Standard',
    Icons.map_outlined,
    'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
  ),
  relief(
    'Relief',
    Icons.terrain_outlined,
    'https://tile.opentopomap.org/{z}/{x}/{y}.png',
  ),
  dark(
    'Sombre',
    Icons.dark_mode_outlined,
    'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
  ),
  satellite(
    'Satellite',
    Icons.satellite_alt_outlined,
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  );

  final String label;
  final IconData icon;
  final String urlTemplate;

  const _DashboardMapStyle(this.label, this.icon, this.urlTemplate);
}
