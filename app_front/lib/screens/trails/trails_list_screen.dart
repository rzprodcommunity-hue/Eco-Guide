import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/eco_page_header.dart';
import '../../core/widgets/error_banner.dart';
import '../../providers/trail_provider.dart';
import '../../models/trail.dart';
import 'trail_detail_screen.dart';

class TrailsListScreen extends StatefulWidget {
  const TrailsListScreen({super.key});

  @override
  State<TrailsListScreen> createState() => _TrailsListScreenState();
}

class _TrailsListScreenState extends State<TrailsListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrailProvider>().loadTrails(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<TrailProvider>().loadMore();
    }
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
        return 'Modérée';
      case 'difficult':
        return 'Difficile';
      default:
        return difficulty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trailProvider = context.watch<TrailProvider>();
    final query = _searchQuery.trim().toLowerCase();
    final displayedTrails = query.isEmpty
        ? trailProvider.trails
        : trailProvider.trails.where((trail) {
        bool startsWithQuery(String text) {
          final value = text.toLowerCase();
          if (value.startsWith(query)) return true;
          return value
            .split(RegExp(r'\s+'))
            .any((word) => word.startsWith(query));
        }

            final name = trail.name.toLowerCase();
            final region = (trail.region ?? '').toLowerCase();
            final description = trail.description.toLowerCase();
        return startsWithQuery(name) ||
          startsWithQuery(region) ||
          startsWithQuery(description);
          }).toList();
    final showLoadMore = query.isEmpty && trailProvider.hasMore;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: const EcoPageHeader(
        title: 'Trails',
        showBackButton: false,
      ),
      body: Column(
        children: [
          // Search Bar and Filter Icon
          _buildSearchBar(context, trailProvider),
          
          // Difficulty Filter Chips
          _buildDifficultyFilter(trailProvider),
          
          // Error Banner
          if (trailProvider.error != null && trailProvider.error!.isNotEmpty)
            ErrorBanner(
              message: trailProvider.error!,
              onRetry: () => trailProvider.loadTrails(refresh: true),
              onDismiss: trailProvider.clearError,
            ),
          
          // Trails List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await trailProvider.loadTrails(refresh: true);
              },
              child: trailProvider.isLoading && trailProvider.trails.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : displayedTrails.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.hiking, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                query.isEmpty
                                    ? 'Aucun sentier trouvé'
                                    : 'Aucun résultat pour "$_searchQuery"',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: displayedTrails.length + (showLoadMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= displayedTrails.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final trail = displayedTrails[index];
                            return _TrailCard(
                              trail: trail,
                              difficultyColor:
                                  _getDifficultyColor(trail.difficulty),
                              difficultyText:
                                  _getDifficultyText(trail.difficulty),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding and Profile Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Eco-Guide',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    'JD',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Main Title
          const Text(
            'Trouvez votre sentier',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, TrailProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFD1D5DB),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Color(0xFF111827)),
                decoration: InputDecoration(
                  hintText: 'Où voulez-vous marcher?',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, color: Colors.white, size: 20),
              onPressed: () => _showAdvancedFilters(context, provider),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyFilter(TrailProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _DifficultyChip(
            label: '✓ Tous les parcours',
            selected: provider.filterDifficulty == null,
            onTap: () => provider.clearAllFilters(),
          ),
          const SizedBox(width: 10),
          _DifficultyChip(
            label: '⛰ Facile',
            selected: provider.filterDifficulty == 'easy',
            onTap: () => provider.setDifficultyFilter('easy'),
          ),
          const SizedBox(width: 10),
          _DifficultyChip(
            label: '⛰⛰ Modérée',
            selected: provider.filterDifficulty == 'moderate',
            onTap: () => provider.setDifficultyFilter('moderate'),
          ),
          const SizedBox(width: 10),
          _DifficultyChip(
            label: '⛰⛰⛰ Difficile',
            selected: provider.filterDifficulty == 'difficult',
            onTap: () => provider.setDifficultyFilter('difficult'),
          ),
        ],
      ),
    );
  }

  void _showAdvancedFilters(BuildContext context, TrailProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterSheet(provider: provider),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DifficultyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.green : const Color(0xFFD1D5DB),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF374151),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TrailCard extends StatelessWidget {
  final Trail trail;
  final Color difficultyColor;
  final String difficultyText;

  const _TrailCard({
    required this.trail,
    required this.difficultyColor,
    required this.difficultyText,
  });

  @override
  Widget build(BuildContext context) {
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
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        // overflow: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trail Image
            if (trail.imageUrls != null && trail.imageUrls!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: trail.imageUrls!.first,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 160,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 160,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, size: 48),
                ),
              )
            else
              Container(
                height: 160,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.landscape, size: 64, color: Colors.grey),
                ),
              ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Difficulty
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trail.name,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: difficultyColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: difficultyColor, width: 0.5),
                        ),
                        child: Text(
                          difficultyText,
                          style: TextStyle(
                            color: difficultyColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Location
                  if (trail.region != null)
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          trail.region!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  // Stats
                  Row(
                    children: [
                      _StatItem(
                        icon: Icons.straighten,
                        label: trail.distanceText,
                      ),
                      const SizedBox(width: 16),
                      _StatItem(
                        icon: Icons.timer_outlined,
                        label: trail.durationText,
                      ),
                      if (trail.elevationGain != null) ...[
                        const SizedBox(width: 16),
                        _StatItem(
                          icon: Icons.trending_up,
                          label: '${trail.elevationGain!.toInt()}m',
                        ),
                      ],
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
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.green),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final TrailProvider provider;

  const _FilterSheet({required this.provider});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _selectedDifficulty;
  late RangeValues _distanceRange;
  late int _selectedDuration;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = widget.provider.filterDifficulty;
    _distanceRange = RangeValues(
      widget.provider.minDistance ?? 0,
      widget.provider.maxDistance ?? 50,
    );
    _selectedDuration = widget.provider.maxDuration ?? 480;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtres avancés',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDifficulty = null;
                    _distanceRange = const RangeValues(0, 50);
                    _selectedDuration = 480;
                  });
                },
                child: const Text('Réinitialiser'),
              ),
            ],
          ),
          // const SizedBox(height: 5),

          // Difficulty Filter
          const Text('Difficulté',
              style: TextStyle(
                color: Color(0xFF111827), fontWeight: FontWeight.bold)),
          const SizedBox(height: 0),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'Tous',
                selected: _selectedDifficulty == null,
                onSelected: () => setState(() => _selectedDifficulty = null),
              ),
              _FilterChip(
                label: 'Facile',
                selected: _selectedDifficulty == 'easy',
                onSelected: () => setState(() => _selectedDifficulty = 'easy'),
              ),
              _FilterChip(
                label: 'Modérée',
                selected: _selectedDifficulty == 'moderate',
                onSelected: () =>
                    setState(() => _selectedDifficulty = 'moderate'),
              ),
              _FilterChip(
                label: 'Difficile',
                selected: _selectedDifficulty == 'difficult',
                onSelected: () =>
                    setState(() => _selectedDifficulty = 'difficult'),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Distance Filter
          const Text('Distance (km)',
              style: TextStyle(
                color: Color(0xFF111827), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          RangeSlider(
            values: _distanceRange,
            min: 0,
            max: 50,
            divisions: 50,
            labels: RangeLabels(
              _distanceRange.start.toStringAsFixed(1),
              _distanceRange.end.toStringAsFixed(1),
            ),
            onChanged: (values) {
              setState(() => _distanceRange = values);
            },
          ),
          const SizedBox(height: 24),

          // Duration Filter
          const Text('Durée maximale',
              style: TextStyle(
                color: Color(0xFF111827), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Slider(
            value: _selectedDuration.toDouble(),
            min: 0,
            max: 600,
            divisions: 60,
            label: _formatDuration(_selectedDuration),
            onChanged: (value) {
              setState(() => _selectedDuration = value.toInt());
            },
          ),
          const SizedBox(height: 24),

          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                widget.provider.setDifficultyFilter(_selectedDifficulty);
                widget.provider.setDistanceFilter(
                  _distanceRange.start,
                  _distanceRange.end,
                );
                widget.provider.setDurationFilter(_selectedDuration);
                Navigator.pop(context);
              },
              child: const Text(
                'Appliquer les filtres',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}min';
    } else if (hours > 0) {
      return '${hours}h';
    }
    return '${mins}min';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}


// class _TrailCard extends StatelessWidget {
//   final Trail trail;
//   final Color difficultyColor;
//   final String difficultyText;

//   const _TrailCard({
//     required this.trail,
//     required this.difficultyColor,
//     required this.difficultyText,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 16),
//       clipBehavior: Clip.antiAlias,
//       child: InkWell(
//         onTap: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (_) => TrailDetailScreen(trail: trail),
//             ),
//           );
//         },
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Image
//             if (trail.imageUrls != null && trail.imageUrls!.isNotEmpty)
//               CachedNetworkImage(
//                 imageUrl: trail.imageUrls!.first,
//                 height: 150,
//                 width: double.infinity,
//                 fit: BoxFit.cover,
//                 placeholder: (_, __) => Container(
//                   height: 150,
//                   color: Colors.grey[200],
//                   child: const Center(child: CircularProgressIndicator()),
//                 ),
//                 errorWidget: (_, __, ___) => Container(
//                   height: 150,
//                   color: Colors.grey[200],
//                   child: const Icon(Icons.image_not_supported, size: 48),
//                 ),
//               )
//             else
//               Container(
//                 height: 150,
//                 color: AppTheme.primaryColor.withValues(alpha: 0.1),
//                 child: const Center(
//                   child: Icon(Icons.landscape, size: 64, color: AppTheme.primaryColor),
//                 ),
//               ),
//             Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Title and difficulty badge
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           trail.name,
//                           style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 8,
//                           vertical: 4,
//                         ),
//                         decoration: BoxDecoration(
//                           color: difficultyColor.withValues(alpha: 0.1),
//                           borderRadius: BorderRadius.circular(4),
//                           border: Border.all(color: difficultyColor),
//                         ),
//                         child: Text(
//                           difficultyText,
//                           style: TextStyle(
//                             color: difficultyColor,
//                             fontSize: 12,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   // Region
//                   if (trail.region != null)
//                     Row(
//                       children: [
//                         const Icon(Icons.location_on, size: 16, color: Colors.grey),
//                         const SizedBox(width: 4),
//                         Text(
//                           trail.region!,
//                           style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                       ],
//                     ),
//                   const SizedBox(height: 8),
//                   // Stats row
//                   Row(
//                     children: [
//                       _StatChip(
//                         icon: Icons.straighten,
//                         label: trail.distanceText,
//                       ),
//                       const SizedBox(width: 16),
//                       _StatChip(
//                         icon: Icons.timer,
//                         label: trail.durationText,
//                       ),
//                       if (trail.elevationGain != null) ...[
//                         const SizedBox(width: 16),
//                         _StatChip(
//                           icon: Icons.trending_up,
//                           label: '${trail.elevationGain!.toInt()}m',
//                         ),
//                       ],
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// class _FilterSheet extends StatefulWidget {
//   final TrailProvider provider;

//   const _FilterSheet({required this.provider});

//   @override
//   State<_FilterSheet> createState() => _FilterSheetState();
// }

// class _FilterSheetState extends State<_FilterSheet> {
//   late String? _selectedDifficulty;
//   late RangeValues _distanceRange;
//   late int _selectedDuration;

//   @override
//   void initState() {
//     super.initState();
//     _selectedDifficulty = widget.provider.filterDifficulty;
//     _distanceRange = RangeValues(
//       widget.provider.minDistance ?? 0,
//       widget.provider.maxDistance ?? 50,
//     );
//     _selectedDuration = widget.provider.maxDuration ?? 480; // 8 hours default
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.only(
//         top: 16,
//         left: 16,
//         right: 16,
//         bottom: MediaQuery.of(context).viewInsets.bottom + 16,
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 'Filtrer les sentiers',
//                 style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               TextButton(
//                 onPressed: () {
//                   setState(() {
//                     _selectedDifficulty = null;
//                     _distanceRange = const RangeValues(0, 50);
//                     _selectedDuration = 480;
//                   });
//                 },
//                 child: const Text('Réinitialiser'),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),

//           // Difficulty Filter
//           Text('Difficulté', style: Theme.of(context).textTheme.titleSmall),
//           const SizedBox(height: 8),
//           Wrap(
//             spacing: 8,
//             children: [
//               _FilterChip(
//                 label: 'Tous',
//                 selected: _selectedDifficulty == null,
//                 onSelected: () => setState(() => _selectedDifficulty = null),
//               ),
//               ...AppConstants.difficulties.map((d) => _FilterChip(
//                 label: _getDifficultyText(d),
//                 selected: _selectedDifficulty == d,
//                 onSelected: () => setState(() => _selectedDifficulty = d),
//               )),
//             ],
//           ),
//           const SizedBox(height: 24),

//           // Distance Filter
//           Text('Distance (km)', style: Theme.of(context).textTheme.titleSmall),
//           const SizedBox(height: 8),
//           RangeSlider(
//             values: _distanceRange,
//             min: 0,
//             max: 50,
//             divisions: 50,
//             labels: RangeLabels(
//               _distanceRange.start.toStringAsFixed(1),
//               _distanceRange.end.toStringAsFixed(1),
//             ),
//             onChanged: (values) {
//               setState(() => _distanceRange = values);
//             },
//           ),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 8),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('${_distanceRange.start.toStringAsFixed(1)} km'),
//                 Text('${_distanceRange.end.toStringAsFixed(1)} km'),
//               ],
//             ),
//           ),
//           const SizedBox(height: 24),

//           // Duration Filter
//           Text('Durée maximale (minutes)', style: Theme.of(context).textTheme.titleSmall),
//           const SizedBox(height: 8),
//           Slider(
//             value: _selectedDuration.toDouble(),
//             min: 0,
//             max: 600, // 10 hours
//             divisions: 60,
//             label: _formatDuration(_selectedDuration),
//             onChanged: (value) {
//               setState(() => _selectedDuration = value.toInt());
//             },
//           ),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 8),
//             child: Text(_formatDuration(_selectedDuration)),
//           ),
//           const SizedBox(height: 24),

//           // Apply Filters Button
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton(
//               onPressed: () {
//                 widget.provider.setDifficultyFilter(_selectedDifficulty);
//                 widget.provider.setDistanceFilter(
//                   _distanceRange.start,
//                   _distanceRange.end,
//                 );
//                 widget.provider.setDurationFilter(_selectedDuration);
//                 Navigator.pop(context);
//               },
//               child: const Text('Appliquer les filtres'),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _getDifficultyText(String difficulty) {
//     switch (difficulty) {
//       case 'easy':
//         return 'Facile';
//       case 'moderate':
//         return 'Modérée';
//       case 'difficult':
//         return 'Difficile';
//       default:
//         return difficulty;
//     }
//   }

//   String _formatDuration(int minutes) {
//     final hours = minutes ~/ 60;
//     final mins = minutes % 60;
//     if (hours > 0 && mins > 0) {
//       return '${hours}h ${mins}min';
//     } else if (hours > 0) {
//       return '${hours}h';
//     }
//     return '${mins}min';
//   }
// }

// class _FilterChip extends StatelessWidget {
//   final String label;
//   final bool selected;
//   final VoidCallback onSelected;

//   const _FilterChip({
//     required this.label,
//     required this.selected,
//     required this.onSelected,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return FilterChip(
//       label: Text(label),
//       selected: selected,
//       onSelected: (_) => onSelected(),
//     );
//   }
// }
