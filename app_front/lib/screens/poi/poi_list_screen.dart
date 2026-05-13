import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/network_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/eco_page_header.dart';
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
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _nearbyCount = 0;
  bool _loadingNearbyCount = false;

  static const List<String> _allPoiTypes = [
    'viewpoint', 'flora', 'fauna', 'historical',
    'water', 'camping', 'danger', 'rest_area', 'information',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPois());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  static IconData _getPoiIcon(String type) {
    switch (type) {
      case 'viewpoint':   return Icons.landscape;
      case 'flora':       return Icons.local_florist;
      case 'fauna':       return Icons.pets;
      case 'historical':  return Icons.account_balance;
      case 'water':       return Icons.water_drop;
      case 'camping':     return Icons.cabin;
      case 'danger':      return Icons.warning_amber_rounded;
      case 'rest_area':   return Icons.weekend;
      case 'information': return Icons.info_outline;
      default:            return Icons.place;
    }
  }

  static Color _getTypeColor(String type) {
    switch (type) {
      case 'fauna':       return const Color(0xFF6D8B5F); // sage green
      case 'flora':       return const Color(0xFF2E7D32); // forest green
      case 'historical':  return const Color(0xFF795548); // warm earth brown
      case 'viewpoint':   return const Color(0xFF3E7B4F); // deep green
      case 'water':       return const Color(0xFF2E6B5E); // muted teal-green
      case 'camping':     return const Color(0xFF5D4E37); // dark earth
      case 'danger':      return const Color(0xFFB33A3A); // muted red
      case 'rest_area':   return const Color(0xFF557A5A); // olive green
      case 'information': return const Color(0xFF546B5E); // grey-green
      default:            return const Color(0xFF2E7D32);
    }
  }

  Future<void> _onFilterSelected(String? type) async {
    setState(() => _selectedType = type);
    await _loadPois();
  }

  Future<void> _loadPois() async {
    final provider = context.read<PoiProvider>();
    final query = _searchController.text.trim();
    await provider.loadPois(
      type: _selectedType,
      search: query.isEmpty ? null : query,
    );
    if (!mounted) return;
    await _refreshNearbyCount(provider);
  }

  Future<void> _refreshPois() async {
    final isOnline = await NetworkService.hasInternetConnection();
    if (!mounted) return;
    final provider = context.read<PoiProvider>();
    final query = _searchController.text.trim();
    await provider.loadPois(
      type: _selectedType,
      search: query.isEmpty ? null : query,
      forceOffline: !isOnline,
    );
    if (!mounted) return;
    await _refreshNearbyCount(provider);
  }

  Future<void> _refreshNearbyCount(PoiProvider provider) async {
    if (provider.pois.isEmpty) {
      setState(() => _nearbyCount = 0);
      return;
    }
    setState(() => _loadingNearbyCount = true);
    try {
      final center = provider.pois.first;
      final nearby = await provider.getNearbyPois(
        center.latitude,
        center.longitude,
        type: _selectedType,
      );
      final currentIds = provider.pois.map((p) => p.id).toSet();
      final others = nearby.where((p) => !currentIds.contains(p.id)).length;
      if (!mounted) return;
      setState(() => _nearbyCount = others);
    } finally {
      if (mounted) setState(() => _loadingNearbyCount = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadPois);
  }

  Future<void> _openLearnMore(BuildContext context, Poi poi) async {
    final link = poi.learnMoreUrl;
    if (link == null || link.trim().isEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PoiDetailScreen(poi: poi)));
      return;
    }
    final uri = Uri.tryParse(link.trim());
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid link for this POI')),
      );
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this link')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PoiProvider>();
    final pois = provider.pois;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;
    final subtleText = onSurface.withValues(alpha: 0.55);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const EcoPageHeader(
        title: 'Local Heritage',
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: _refreshPois,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ── Subtitle & Stats ────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Discover the wonders of the Vercors ecosystem',
                    style: TextStyle(
                      fontSize: 13,
                      color: subtleText,
                      height: 1.4,
                    ),
                  ),
                ),
                if (!provider.isLoading && pois.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '${pois.length} POIs',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Search Bar ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: TextStyle(color: onSurface, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un point d\'intérêt...',
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: Color(0xFF6B7280), size: 20),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _loadPois();
                      setState(() {});
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                      ),
                      child: Icon(Icons.close_rounded, size: 18, color: subtleText),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // ── Filter Chips ─────────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TypeFilterChip(
                    label: 'All',
                    icon: Icons.apps_rounded,
                    isSelected: _selectedType == null,
                    color: const Color(0xFF2E7D32),
                    onTap: () => _onFilterSelected(null),
                    isDark: isDark,
                  ),
                  ..._allPoiTypes.map(
                    (type) => _TypeFilterChip(
                      label: _formatType(type),
                      icon: _getPoiIcon(type),
                      isSelected: _selectedType == type,
                      color: _getTypeColor(type),
                      onTap: () => _onFilterSelected(type),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Error ────────────────────────────────────────────────────────
            if (provider.error != null && provider.error!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ErrorBanner(
                  message: provider.error!,
                  onRetry: _loadPois,
                  onDismiss: provider.clearError,
                ),
              ),

            // ── Loading ──────────────────────────────────────────────────────
            if (provider.isLoading && pois.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: AppTheme.primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Loading points of interest...',
                        style: TextStyle(
                          color: subtleText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )

            // ── Empty State ──────────────────────────────────────────────────
            else if (pois.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.place_outlined,
                          size: 48,
                          color: AppTheme.primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No results found',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try adjusting your search or filter',
                        style: TextStyle(
                          fontSize: 13,
                          color: subtleText,
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          _onFilterSelected(null);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Clear filters'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )

            // ── POI Cards ────────────────────────────────────────────────────
            else ...[
              ...List.generate(
                pois.length,
                (index) => _PoiCard(
                  poi: pois[index],
                  icon: _getPoiIcon(pois[index].type),
                  typeColor: _getTypeColor(pois[index].type),
                  isFeatured: index == 0,
                  isDark: isDark,
                  onTapLearnMore: () => _openLearnMore(context, pois[index]),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PoiDetailScreen(poi: pois[index])),
                  ),
                ),
              ),
              _MapCard(
                center: LatLng(pois.first.latitude, pois.first.longitude),
                nearbyCount: _loadingNearbyCount ? null : _nearbyCount,
                isDark: isDark,
                onTapOpenMap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapScreen()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatType(String type) {
    return type.split('_').map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}').join(' ');
  }
}

// ── POI Card ─────────────────────────────────────────────────────────────────

class _PoiCard extends StatelessWidget {
  final Poi poi;
  final IconData icon;
  final Color typeColor;
  final bool isFeatured;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onTapLearnMore;

  const _PoiCard({
    required this.poi,
    required this.icon,
    required this.typeColor,
    required this.isFeatured,
    required this.isDark,
    required this.onTap,
    required this.onTapLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final onSurface = theme.colorScheme.onSurface;
    final subtleText = onSurface.withValues(alpha: 0.55);
    final imageHeight = isFeatured ? 200.0 : 160.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          if (!isDark)
            BoxShadow(
              color: typeColor.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image ──────────────────────────────────────────────────────
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Stack(
                  children: [
                    SizedBox(
                      height: imageHeight,
                      width: double.infinity,
                      child: poi.mediaUrl != null
                          ? CachedNetworkImage(
                              imageUrl: poi.mediaUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _FallbackImage(
                                icon: icon,
                                color: typeColor,
                              ),
                            )
                          : _FallbackImage(icon: icon, color: typeColor),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Type badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: typeColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: typeColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 12, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              poi.typeDisplayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Featured badge
                    if (isFeatured)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 11, color: Color(0xFFFFD54F)),
                              SizedBox(width: 4),
                              Text(
                                'Featured',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Name overlay at bottom of image
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Text(
                        poi.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 8),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Content ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poi.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtleText,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badge chip — compact, auto-width
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: typeColor.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 11, color: typeColor),
                              const SizedBox(width: 5),
                              Text(
                                poi.badge?.trim().isNotEmpty == true
                                    ? poi.badge!
                                    : poi.typeDisplayName,
                                style: TextStyle(
                                  color: typeColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Learn More — compact pill
                        GestureDetector(
                          onTap: onTapLearnMore,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'En savoir plus',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                              ],
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
        ),
      ),
    );
  }
}

// ── Fallback Image ────────────────────────────────────────────────────────────

class _FallbackImage extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _FallbackImage({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 52),
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────

class _TypeFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _TypeFilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipBg = isSelected ? color : theme.cardColor;
    final borderCol = isSelected ? color : theme.colorScheme.outline;
    final iconCol = isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final labelCol = isSelected ? Colors.white : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        child: Material(
          color: chipBg,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderCol),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: iconCol),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: labelCol,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Map Card ──────────────────────────────────────────────────────────────────

class _MapCard extends StatelessWidget {
  final LatLng center;
  final int? nearbyCount;
  final bool isDark;
  final VoidCallback onTapOpenMap;

  const _MapCard({
    required this.center,
    required this.nearbyCount,
    required this.isDark,
    required this.onTapOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore Nearby POIs',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nearbyCount == null
                            ? 'Searching nearby points...'
                            : nearbyCount! > 0
                                ? '$nearbyCount more points nearby'
                                : 'All nearby points shown',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onTapOpenMap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Open Map',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
          // Map
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            child: Stack(
              children: [
                SizedBox(
                  height: 150,
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
                            'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                        userAgentPackageName: 'com.ecoguide.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: center,
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.location_pin,
                              color: AppTheme.primaryColor,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Attribution
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap',
                      style: TextStyle(fontSize: 9, color: Colors.black54),
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
