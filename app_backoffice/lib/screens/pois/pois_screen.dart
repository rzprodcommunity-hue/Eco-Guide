import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../core/providers/pois_provider.dart';
import '../../core/models/poi_model.dart';
import '../../core/constants/app_colors.dart';

class PoisScreen extends StatefulWidget {
  const PoisScreen({super.key});

  @override
  State<PoisScreen> createState() => _PoisScreenState();
}

class _PoisScreenState extends State<PoisScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoisProvider>().loadPois();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PoisProvider>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${provider.total} points d\'interet au total',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/pois/create'),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau POI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
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
                      provider.loadPois();
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

  Widget _buildDataTable(PoisProvider provider) {
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
              DataColumn2(label: Text('Type')),
              DataColumn2(label: Text('Coordonnees')),
              DataColumn2(label: Text('Statut')),
              DataColumn2(label: Text('Actions'), fixedWidth: 120),
            ],
            rows: provider.pois.map((poi) => _buildRow(poi, provider)).toList(),
          ),
        ),
        _buildPagination(provider),
      ],
    );
  }

  DataRow _buildRow(PoiModel poi, PoisProvider provider) {
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              if (poi.mediaUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    poi.mediaUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(poi.type),
                  ),
                )
              else
                _buildPlaceholder(poi.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      poi.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      poi.description,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DataCell(_buildTypeChip(poi.type)),
        DataCell(Text('${poi.latitude.toStringAsFixed(4)}, ${poi.longitude.toStringAsFixed(4)}')),
        DataCell(_buildStatusChip(poi.isActive)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => context.go('/pois/edit/${poi.id}'),
                icon: const Icon(Icons.edit, color: AppColors.secondary),
                tooltip: 'Modifier',
              ),
              IconButton(
                onPressed: () => _confirmDelete(poi, provider),
                icon: const Icon(Icons.delete, color: AppColors.error),
                tooltip: 'Supprimer',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(PoiType type) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_getTypeIcon(type), color: AppColors.textHint),
    );
  }

  IconData _getTypeIcon(PoiType type) {
    switch (type) {
      case PoiType.viewpoint:
        return Icons.landscape;
      case PoiType.flora:
        return Icons.local_florist;
      case PoiType.fauna:
        return Icons.pets;
      case PoiType.historical:
        return Icons.account_balance;
      case PoiType.water:
        return Icons.water_drop;
      case PoiType.camping:
        return Icons.cabin;
      case PoiType.danger:
        return Icons.warning;
      case PoiType.rest_area:
        return Icons.weekend;
      case PoiType.information:
        return Icons.info;
    }
  }

  Widget _buildTypeChip(PoiType type) {
    final colors = {
      PoiType.viewpoint: Colors.blue,
      PoiType.flora: Colors.green,
      PoiType.fauna: Colors.orange,
      PoiType.historical: Colors.purple,
      PoiType.water: Colors.cyan,
      PoiType.camping: Colors.brown,
      PoiType.danger: Colors.red,
      PoiType.rest_area: Colors.teal,
      PoiType.information: Colors.indigo,
    };

    final labels = {
      PoiType.viewpoint: 'Point de vue',
      PoiType.flora: 'Flore',
      PoiType.fauna: 'Faune',
      PoiType.historical: 'Historique',
      PoiType.water: 'Eau',
      PoiType.camping: 'Camping',
      PoiType.danger: 'Danger',
      PoiType.rest_area: 'Repos',
      PoiType.information: 'Info',
    };

    final color = colors[type] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        labels[type] ?? type.name,
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

  Widget _buildPagination(PoisProvider provider) {
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
                ? () => provider.loadPois(page: provider.currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 16),
          Text('Page ${provider.currentPage} sur ${provider.totalPages}'),
          const SizedBox(width: 16),
          IconButton(
            onPressed: provider.currentPage < provider.totalPages
                ? () => provider.loadPois(page: provider.currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(PoiModel poi, PoisProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer le POI "${poi.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.deletePoi(poi.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
