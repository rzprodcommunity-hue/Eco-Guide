import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/eco_page_header.dart';
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
      _detectUserPosition();
    });
  }

  void _loadData() {
    context.read<TrailProvider>().loadTrails(refresh: true);
    context.read<PoiProvider>().loadPois();
    context.read<WeatherProvider>().loadCurrentWeather(
      lat: _currentPosition.latitude,
      lng: _currentPosition.longitude,
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
      context.read<WeatherProvider>().loadCurrentWeather(
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
      backgroundColor: const Color(0xFFF8F9FA),
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
                  _buildNearbyPois(poiProvider),
                  const SizedBox(height: 24),
                  _buildCurrentConditions(weatherProvider),
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
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
                    urlTemplate: _mapStyle.urlTemplate,
                    userAgentPackageName: 'com.ecoguide.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentPosition,
                        width: 24,
                        height: 24,
                        child: GestureDetector(
                          onTap: () => _mapController.move(_currentPosition, 15),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Location Label
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Reserve Naturelle',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Action Buttons
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  children: [
                    _buildMapButton(
                      icon: Icons.layers_outlined,
                      onTap: _cycleMapStyle,
                    ),
                    const SizedBox(height: 8),
                    _buildMapButton(
                      icon: Icons.my_location,
                      onTap: () {
                        _mapController.move(_currentPosition, 14);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMapButton(
                      icon: Icons.open_in_full,
                      onTap: () => widget.onNavigateToMap?.call(),
                    ),
                  ],
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
    final modeNumber = nextIndex + 1;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 900),
        content: Text('Mode $modeNumber: ${nextStyle.label}'),
      ),
    );
  }

  Widget _buildMapButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: const Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildQuickActionItem(
            icon: Icons.terrain,
            label: 'Trails',
            color: const Color(0xFF4CAF50),
            onTap: widget.onNavigateToTrails,
          ),
          _buildQuickActionItem(
            icon: Icons.map_outlined,
            label: 'Offline Maps',
            color: const Color(0xFF2196F3),
            onTap: widget.onNavigateToOffline,
          ),
          _buildQuickActionItem(
            icon: Icons.explore_outlined,
            label: 'Quiz Educatif',
            color: const Color(0xFF9C27B0),
            onTap: widget.onNavigateToQuiz,
          ),
          _buildQuickActionItem(
            icon: Icons.sos,
            label: 'SOS',
            color: const Color(0xFFE53935),
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
              const Text(
                'Nearby POI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
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
                          padding: EdgeInsets.only(right: index < pois.length - 1 ? 12 : 0),
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
          color: Colors.white,
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: hasImage
                    ? Image.network(
                        poi.mediaUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPoiImagePlaceholder(),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    poi.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      Icon(Icons.near_me, size: 13, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${distanceKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
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
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyTrails(TrailProvider trailProvider) {
    final trails = trailProvider.trails.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nearby Trails',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: widget.onNavigateToTrails,
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
          height: 220,
          child: trailProvider.isLoading && trails.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : trails.isEmpty
                  ? const Center(
                      child: Text('No trails available'),
                    )
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
          MaterialPageRoute(
            builder: (_) => TrailDetailScreen(trail: trail),
          ),
        );
      },
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
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
                      color: Colors.white,
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
                        Text(
                          '4.8',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Difficulty badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isEasy
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isEasy ? 'Easy' : 'Hard',
                      style: const TextStyle(
                        fontSize: 10,
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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trail.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.straighten,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trail.distanceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trail.durationText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.terrain,
          size: 40,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildCurrentConditions(WeatherProvider weatherProvider) {
    final weather = weatherProvider.currentWeather;
    final isLoading = weatherProvider.isLoading && weather == null;

    final condition = weather?.condition ?? 'Variable';
    final summary = weather?.summary ?? 'Weather data loading...';
    final temperature = weather?.temperatureText ?? '--°C';
    final wind = weather?.windText ?? '-- km/h';
    final humidity = weather?.humidityText ?? '--%';
    final icon = _weatherIcon(weather?.weatherCode ?? -1, weather?.isDay ?? true);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF29B6F6).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Conditions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      temperature,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isLoading ? 'Updating weather...' : summary,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildWeatherInfo(Icons.air, 'Wind', wind),
                const SizedBox(width: 24),
                _buildWeatherInfo(Icons.water_drop, 'Humidity', humidity),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              weatherProvider.error != null
                  ? 'Live weather unavailable. Showing latest data.'
                  : condition,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _weatherIcon(int weatherCode, bool isDay) {
    if (weatherCode == 0) {
      return isDay ? Icons.wb_sunny : Icons.nights_stay;
    }
    if ([1, 2, 3].contains(weatherCode)) {
      return Icons.cloud_queue;
    }
    if ([61, 63, 65, 80, 81, 82, 51, 53, 55, 56, 57].contains(weatherCode)) {
      return Icons.umbrella;
    }
    if ([71, 73, 75, 77, 85, 86].contains(weatherCode)) {
      return Icons.ac_unit;
    }
    if ([95, 96, 99].contains(weatherCode)) {
      return Icons.thunderstorm;
    }
    return Icons.cloud;
  }

  Widget _buildWeatherInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.white70,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStartTrekButton() {
    return Positioned(
      right: 20,
      bottom: 20,
      child: FloatingActionButton.extended(
        heroTag: 'startTrekDashboard',
        onPressed: widget.onNavigateToTrails,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.play_arrow, color: Colors.white),
        label: const Text(
          'Start Exploring',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

enum _DashboardMapStyle {
  standard('Normal', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
  relief('Relief', 'https://tile.opentopomap.org/{z}/{x}/{y}.png'),
  dark('Noir', 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'),
  satellite('Satellite', 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}');

  final String label;
  final String urlTemplate;

  const _DashboardMapStyle(this.label, this.urlTemplate);
}
