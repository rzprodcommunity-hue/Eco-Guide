import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
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
        return 'Modere';
      case 'difficult':
        return 'Difficile';
      default:
        return difficulty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trailProvider = context.watch<TrailProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentiers'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              trailProvider.setDifficultyFilter(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Tous'),
              ),
              ...AppConstants.difficulties.map((d) => PopupMenuItem(
                value: d,
                child: Text(_getDifficultyText(d)),
              )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
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
                  : trailProvider.trails.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.hiking, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Aucun sentier trouve'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: trailProvider.trails.length +
                              (trailProvider.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= trailProvider.trails.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final trail = trailProvider.trails[index];
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrailDetailScreen(trail: trail),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (trail.imageUrls != null && trail.imageUrls!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: trail.imageUrls!.first,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, size: 48),
                ),
              )
            else
              Container(
                height: 150,
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: const Center(
                  child: Icon(Icons.landscape, size: 64, color: AppTheme.primaryColor),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and difficulty badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trail.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: difficultyColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: difficultyColor),
                        ),
                        child: Text(
                          difficultyText,
                          style: TextStyle(
                            color: difficultyColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Region
                  if (trail.region != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          trail.region!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  // Stats row
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.straighten,
                        label: trail.distanceText,
                      ),
                      const SizedBox(width: 16),
                      _StatChip(
                        icon: Icons.timer,
                        label: trail.durationText,
                      ),
                      if (trail.elevationGain != null) ...[
                        const SizedBox(width: 16),
                        _StatChip(
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
