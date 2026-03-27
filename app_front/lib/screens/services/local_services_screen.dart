import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/eco_page_header.dart';
import '../../core/widgets/error_banner.dart';
import '../../providers/local_service_provider.dart';
import '../../models/local_service.dart';
import 'local_service_detail_screen.dart';

class LocalServicesScreen extends StatefulWidget {
  const LocalServicesScreen({super.key});

  @override
  State<LocalServicesScreen> createState() => _LocalServicesScreenState();
}

class _LocalServicesScreenState extends State<LocalServicesScreen> {
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  final List<Map<String, dynamic>> _categories = [
    {'key': null, 'label': 'Tous', 'icon': Icons.apps},
    {'key': 'accommodation', 'label': 'Hebergements', 'icon': Icons.hotel},
    {'key': 'artisan', 'label': 'Artisans', 'icon': Icons.handyman},
    {'key': 'guide', 'label': 'Guides', 'icon': Icons.person},
    {'key': 'restaurant', 'label': 'Restaurants', 'icon': Icons.restaurant},
    {'key': 'transport', 'label': 'Transport', 'icon': Icons.directions_car},
    {'key': 'equipment', 'label': 'Equipement', 'icon': Icons.backpack},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalServiceProvider>().loadServices();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String? category) {
    setState(() {
      _selectedCategory = category;
    });
    context.read<LocalServiceProvider>().setCategoryFilter(category);
  }

  Future<void> _loadServices() {
    return context.read<LocalServiceProvider>().loadServices(
      category: _selectedCategory,
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      _loadServices,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocalServiceProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const EcoPageHeader(
        title: 'Annuaire Local',
        showBackButton: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (provider.error != null && provider.error!.isNotEmpty)
              ErrorBanner(
                message: provider.error!,
                onRetry: provider.loadServices,
                onDismiss: provider.clearError,
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadServices();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildSearchBar(),
                      const SizedBox(height: 14),
                      _buildCategoryFilters(),
                      const SizedBox(height: 24),
                      _buildSectionHeader(provider),
                      const SizedBox(height: 16),
                      _buildServicesList(provider),
                      const SizedBox(height: 24),
                      _buildMapSection(provider),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.store,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Annuaire Local',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Text(
                    'Soutenez l\'economie durable',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isTyping = _searchController.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: isTyping ? const Color(0xFFF7FFF8) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isTyping ? Colors.green : const Color(0xFFD1D5DB),
            width: isTyping ? 1.4 : 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: 'Rechercher un etablissement...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: isTyping ? Colors.green : Colors.grey[500],
              size: 20,
            ),
            suffixIcon: isTyping
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                      _loadServices();
                    },
                    icon: const Icon(Icons.close, size: 18),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category['key'];

          return Padding(
            padding: EdgeInsets.only(right: index < _categories.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: () => _onCategorySelected(category['key']),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      category['icon'] as IconData,
                      size: 18,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(LocalServiceProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Etablissements Eco-responsables',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${provider.services.length} resultats',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          // TextButton(
          //   onPressed: () {},
          //   child: Text(
          //     'Voir tout',
          //     style: TextStyle(
          //       color: AppTheme.primaryColor,
          //       fontWeight: FontWeight.w600,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildServicesList(LocalServiceProvider provider) {
    if (provider.isLoading && provider.services.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.services.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Aucun etablissement trouve',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: provider.services.length,
      itemBuilder: (context, index) {
        final service = provider.services[index];
        return _ServiceCard(
          service: service,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LocalServiceDetailScreen(
                  serviceId: service.id,
                  fallbackService: service,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapSection(LocalServiceProvider provider) {
    final servicesWithLocation = provider.services
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();

    final centerLat = servicesWithLocation.isNotEmpty
        ? servicesWithLocation.map((s) => s.latitude!).reduce((a, b) => a + b) /
            servicesWithLocation.length
        : AppConstants.defaultLatitude;
    final centerLng = servicesWithLocation.isNotEmpty
        ? servicesWithLocation.map((s) => s.longitude!).reduce((a, b) => a + b) /
            servicesWithLocation.length
        : AppConstants.defaultLongitude;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.map,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Autour de vous',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 160,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(centerLat, centerLng),
                    initialZoom: 12,
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
                    MarkerLayer(
                      markers: servicesWithLocation.map((service) {
                        return Marker(
                          point: LatLng(service.latitude!, service.longitude!),
                          width: 36,
                          height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              _getCategoryIcon(service.category),
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('Ouvrir la carte interactive'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey[300]!),
                    foregroundColor: Colors.grey[700],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'guide':
        return Icons.person;
      case 'artisan':
        return Icons.handyman;
      case 'accommodation':
        return Icons.hotel;
      case 'restaurant':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'equipment':
        return Icons.backpack;
      default:
        return Icons.store;
    }
  }
}

class _ServiceCard extends StatelessWidget {
  final LocalService service;
  final VoidCallback onTap;

  const _ServiceCard({required this.service, required this.onTap});

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'guide':
        return Icons.person;
      case 'artisan':
        return Icons.handyman;
      case 'accommodation':
        return Icons.hotel;
      case 'restaurant':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'equipment':
        return Icons.backpack;
      default:
        return Icons.store;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Image with rating
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: service.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: service.imageUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 160,
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (_, __, ___) => _buildPlaceholderImage(),
                      )
                    : _buildPlaceholderImage(),
              ),
              // Rating badge
              if (service.rating != null)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: Color(0xFFFFB800),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          service.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Verified badge
              if (service.isVerified)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Verifie',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Title and price row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        service.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Description
                Text(
                  service.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                // Tags row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Location tag
                    if (service.address != null)
                      _buildTag(
                        Icons.location_on_outlined,
                        service.address!.length > 20
                            ? '${service.address!.substring(0, 20)}...'
                            : service.address!,
                        Colors.blue,
                      ),
                    // Category tag
                    _buildTag(
                      _getCategoryIcon(service.category),
                      service.categoryDisplayName,
                      AppTheme.primaryColor,
                    ),
                    // Languages
                    if (service.languages != null && service.languages!.isNotEmpty)
                      _buildTag(
                        Icons.language,
                        service.languages!.take(2).join(', '),
                        Colors.purple,
                      ),
                  ],
                ),
                  // const SizedBox(height: 14),
                  // Row(
                  //   children: [
                  //     Text(
                  //       'Voir plus de details',
                  //       style: TextStyle(
                  //         color: AppTheme.primaryColor,
                  //         fontWeight: FontWeight.w700,
                  //       ),
                  //     ),
                  //     const SizedBox(width: 6),
                  //     Icon(
                  //       Icons.arrow_forward,
                  //       size: 16,
                  //       color: AppTheme.primaryColor,
                  //     ),
                  //   ],
                  // ),
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
      height: 160,
      width: double.infinity,
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          _getCategoryIcon(service.category),
          size: 48,
          color: AppTheme.primaryColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
