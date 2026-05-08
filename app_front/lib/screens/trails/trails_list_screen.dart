import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
      backgroundColor: const Color(0xFFFBF9F6),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildSearchBar(context, trailProvider),
            _buildDifficultyFilter(trailProvider),
            if (trailProvider.error != null && trailProvider.error!.isNotEmpty)
              ErrorBanner(
                message: trailProvider.error!,
                onRetry: () => trailProvider.loadTrails(refresh: true),
                onDismiss: trailProvider.clearError,
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await trailProvider.loadTrails(refresh: true);
                },
                child: trailProvider.isLoading && trailProvider.trails.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : displayedTrails.isEmpty
                        ? ListView(
                            children: [
                              _buildOfflineBanner(),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 64),
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
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(top: 8, bottom: 20),
                            itemCount: displayedTrails.length + (showLoadMore ? 1 : 0) + 2,
                            itemBuilder: (context, index) {
                              if (index == 0) return _buildOfflineBanner();
                              if (index == 1) return _buildSectionTitle();

                              final trailIndex = index - 2;
                              if (trailIndex >= displayedTrails.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final trail = displayedTrails[trailIndex];
                              return _TrailCard(
                                trail: trail,
                                difficultyColor: _getDifficultyColor(trail.difficulty),
                                difficultyText: _getDifficultyText(trail.difficulty),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Eco-Guide',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Trouvez votre sentier',
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'JD',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, TrailProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Où voulez-vous marcher ?',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Color(0xFF6B7280), size: 20),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, color: Colors.white, size: 20),
              onPressed: () => _showAdvancedFilters(context, provider),
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
            label: 'Tous les parcours',
            icon: Icons.check_circle,
            selected: provider.filterDifficulty == null,
            onTap: () => provider.clearAllFilters(),
          ),
          const SizedBox(width: 8),
          _DifficultyChip(
            label: 'Facile',
            icon: Icons.terrain,
            selected: provider.filterDifficulty == 'easy',
            onTap: () => provider.setDifficultyFilter('easy'),
          ),
          const SizedBox(width: 8),
          _DifficultyChip(
            label: 'Modéré',
            icon: Icons.terrain,
            selected: provider.filterDifficulty == 'moderate',
            onTap: () => provider.setDifficultyFilter('moderate'),
          ),
          const SizedBox(width: 8),
          _DifficultyChip(
            label: 'Difficile',
            icon: Icons.terrain,
            selected: provider.filterDifficulty == 'difficult',
            onTap: () => provider.setDifficultyFilter('difficult'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Prêt pour l'aventure ?",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Téléchargez les cartes pour un accès hors-ligne complet.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download, size: 16, color: Color(0xFF2E7D32)),
            label: const Text(
              "Télécharger les cartes",
              style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Sentiers recommandés',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.sort, size: 16, color: Color(0xFF6B7280)),
            label: const Text(
              'Trier',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
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
  final IconData? icon;

  const _DifficultyChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E7D32) : const Color(0xFFF6F3ED),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFF2E7D32) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? Colors.white : const Color(0xFF4B5563)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF4B5563),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
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
        margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F3ED),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: trail.imageUrls != null && trail.imageUrls!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: trail.imageUrls!.first,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(height: 180, color: Colors.grey[300]),
                          errorWidget: (_, __, ___) => Container(height: 180, color: Colors.grey[300], child: const Icon(Icons.image_not_supported)),
                        )
                      : Container(
                          height: 180,
                          width: double.infinity,
                          color: Colors.grey[300],
                          child: const Icon(Icons.landscape, size: 48, color: Colors.grey),
                        ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.terrain, size: 14, color: difficultyColor),
                        const SizedBox(width: 4),
                        Text(
                          difficultyText,
                          style: TextStyle(color: difficultyColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          trail.averageRating?.toStringAsFixed(1) ?? '4.8',
                          style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trail.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Color(0xFF6B7280)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    trail.region ?? 'Parc National',
                                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.favorite_border, color: Color(0xFF6B7280), size: 24),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatColumn(
                        label: 'Distance',
                        value: trail.distanceText,
                        icon: Icons.straighten,
                        iconColor: Colors.green,
                      ),
                      _StatColumn(
                        label: 'Durée',
                        value: trail.durationText,
                        icon: Icons.access_time,
                        iconColor: Colors.green,
                      ),
                      _StatColumn(
                        label: 'Dénivelé',
                        value: trail.elevationGain != null ? '+${trail.elevationGain!.toInt()} m' : '+430 m',
                        icon: Icons.trending_up,
                        iconColor: Colors.green,
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
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
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

