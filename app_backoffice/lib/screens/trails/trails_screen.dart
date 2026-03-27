import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../core/providers/trails_provider.dart';
import '../../core/models/trail_model.dart';
import '../../core/constants/app_colors.dart';

class TrailsScreen extends StatefulWidget {
  const TrailsScreen({super.key});

  @override
  State<TrailsScreen> createState() => _TrailsScreenState();
}

class _TrailsScreenState extends State<TrailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrailsProvider>().loadTrails();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrailsProvider>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${provider.total} sentiers au total',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/trails/create'),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau Sentier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filter Bar
          _buildFilterBar(provider),
          const SizedBox(height: 16),
          // Error Banner
          if (provider.error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Erreur de chargement',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider.error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      provider.clearError();
                      provider.loadTrails();
                    },
                    icon: const Icon(Icons.refresh, color: AppColors.error),
                    tooltip: 'Reessayer',
                  ),
                ],
              ),
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildDataTable(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(TrailsProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (provider.hasActiveFilters)
            Tooltip(
              message: 'Effacer les filtres',
              child: TextButton.icon(
                onPressed: () => provider.clearAllFilters(),
                icon: const Icon(Icons.clear),
                label: const Text('Réinitialiser filtres'),
              ),
            ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showFilterDialog(provider),
            icon: const Icon(Icons.filter_list),
            label: const Text('Filtrer'),
          ),
          if (provider.filterDifficulty != null) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text('Difficulté: ${provider.filterDifficulty}'),
              onDeleted: () => provider.setDifficultyFilter(null),
            ),
          ],
          if (provider.minDistance != null || provider.maxDistance != null) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text('Distance: ${provider.minDistance ?? 0}-${provider.maxDistance ?? 50}km'),
              onDeleted: () => provider.setDistanceFilter(null, null),
            ),
          ],
          if (provider.maxDuration != null) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text('Durée max: ${_formatDuration(provider.maxDuration!)}'),
              onDeleted: () => provider.setDurationFilter(null),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterDialog(TrailsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => _TrailFilterDialog(provider: provider),
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

  Widget _buildDataTable(TrailsProvider provider) {
    return Column(
      children: [
        Expanded(
          child: DataTable2(
            columnSpacing: 16,
            horizontalMargin: 16,
            minWidth: 800,
            headingRowColor: WidgetStateProperty.all(AppColors.background),
            columns: const [
              DataColumn2(label: Text('Nom'), size: ColumnSize.L),
              DataColumn2(label: Text('Region')),
              DataColumn2(label: Text('Distance')),
              DataColumn2(label: Text('Difficulte')),
              DataColumn2(label: Text('Duree')),
              DataColumn2(label: Text('Statut')),
              DataColumn2(label: Text('Actions'), fixedWidth: 120),
            ],
            rows: provider.trails
                .map((trail) => _buildRow(trail, provider))
                .toList(),
          ),
        ),
        _buildPagination(provider),
      ],
    );
  }

  DataRow _buildRow(TrailModel trail, TrailsProvider provider) {
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              if (trail.imageUrls?.isNotEmpty == true)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    trail.imageUrls!.first,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: AppColors.background,
                      child: const Icon(Icons.hiking, color: AppColors.textHint),
                    ),
                  ),
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.hiking, color: AppColors.textHint),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  trail.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(trail.region ?? '-')),
        DataCell(Text('${trail.distance} km')),
        DataCell(_buildDifficultyChip(trail.difficulty)),
        DataCell(Text(trail.durationFormatted)),
        DataCell(_buildStatusChip(trail.isActive)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => context.go('/trails/edit/${trail.id}'),
                icon: const Icon(Icons.edit, color: AppColors.secondary),
                tooltip: 'Modifier',
              ),
              IconButton(
                onPressed: () => _confirmDelete(trail, provider),
                icon: const Icon(Icons.delete, color: AppColors.error),
                tooltip: 'Supprimer',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyChip(TrailDifficulty difficulty) {
    Color color;
    switch (difficulty) {
      case TrailDifficulty.easy:
        color = AppColors.success;
        break;
      case TrailDifficulty.moderate:
        color = AppColors.warning;
        break;
      case TrailDifficulty.difficult:
        color = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        difficulty.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success.withOpacity(0.1) : AppColors.textHint.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Actif' : 'Inactif',
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPagination(TrailsProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: provider.currentPage > 1
                ? () => provider.loadTrails(page: provider.currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 16),
          Text('Page ${provider.currentPage} sur ${provider.totalPages}'),
          const SizedBox(width: 16),
          IconButton(
            onPressed: provider.currentPage < provider.totalPages
                ? () => provider.loadTrails(page: provider.currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(TrailModel trail, TrailsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer le sentier "${trail.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.deleteTrail(trail.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _TrailFilterDialog extends StatefulWidget {
  final TrailsProvider provider;

  const _TrailFilterDialog({required this.provider});

  @override
  State<_TrailFilterDialog> createState() => _TrailFilterDialogState();
}

class _TrailFilterDialogState extends State<_TrailFilterDialog> {
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
    _selectedDuration = widget.provider.maxDuration ?? 480; // 8 hours default
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtrer les sentiers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Difficulty Filter
              const Text('Difficulté', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
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
                    onSelected: () => setState(() => _selectedDifficulty = 'moderate'),
                  ),
                  _FilterChip(
                    label: 'Difficile',
                    selected: _selectedDifficulty == 'difficult',
                    onSelected: () => setState(() => _selectedDifficulty = 'difficult'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Distance Filter
              const Text('Distance (km)', style: TextStyle(fontWeight: FontWeight.bold)),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_distanceRange.start.toStringAsFixed(1)} km'),
                    Text('${_distanceRange.end.toStringAsFixed(1)} km'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Duration Filter
              const Text('Durée maximale (minutes)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Slider(
                value: _selectedDuration.toDouble(),
                min: 0,
                max: 600, // 10 hours
                divisions: 60,
                label: _formatDuration(_selectedDuration),
                onChanged: (value) {
                  setState(() => _selectedDuration = value.toInt());
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(_formatDuration(_selectedDuration)),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
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
                  ElevatedButton(
                    onPressed: () {
                      widget.provider.setDifficultyFilter(_selectedDifficulty);
                      widget.provider.setDistanceFilter(
                        _distanceRange.start,
                        _distanceRange.end,
                      );
                      widget.provider.setDurationFilter(_selectedDuration);
                      Navigator.pop(context);
                    },
                    child: const Text('Appliquer'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
