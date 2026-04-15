import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/eco_page_header.dart';
import '../../services/offline_cache_service.dart';
import '../../services/seed_data_service.dart';

/// Screen to manage seed data initialization
/// Useful for testing and for users who want to reload default offline data
class SeedDataManagerScreen extends StatefulWidget {
  const SeedDataManagerScreen({super.key});

  @override
  State<SeedDataManagerScreen> createState() => _SeedDataManagerScreenState();
}

class _SeedDataManagerScreenState extends State<SeedDataManagerScreen> {
  bool _isLoading = false;
  String? _statusMessage;
  Map<String, dynamic>? _offlineStats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await OfflineCacheService.instance.getAllOfflineData();
    if (mounted) {
      setState(() {
        _offlineStats = stats;
      });
    }
  }

  Future<void> _loadSeedData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final seedTrails = SeedDataService.getSeedTrails();
      final seedPois = SeedDataService.getSeedPois();
      final seedServices = SeedDataService.getSeedLocalServices();

      await OfflineCacheService.instance.replaceTrails(
        seedTrails,
        'Moyenne',
        12.5,
      );
      await OfflineCacheService.instance.replacePois(seedPois);
      await OfflineCacheService.instance.replaceLocalServices(seedServices);

      await _loadStats();

      if (mounted) {
        setState(() {
          _statusMessage =
              'Données de Jebel Chitana chargées avec succès!\n'
              '${seedTrails.length} sentiers, ${seedPois.length} POIs, '
              '${seedServices.length} services locaux';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Données hors ligne initialisées avec succès!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Erreur: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer toutes les données hors ligne?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      await OfflineCacheService.instance.clearOfflineTrails();
      await OfflineCacheService.instance.clearOfflinePois();
      await OfflineCacheService.instance.clearOfflineLocalServices();

      await _loadStats();

      if (mounted) {
        setState(() {
          _statusMessage = 'Toutes les données hors ligne ont été supprimées';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Données supprimées'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const EcoPageHeader(title: 'Gestion Données Hors Ligne'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 20),
                  _buildStatsCard(),
                  const SizedBox(height: 20),
                  _buildActionsCard(),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 20),
                    _buildStatusCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.9),
            AppTheme.primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Données de Jebel Chitana',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Cette fonctionnalité permet de charger des données réalistes '
            'pour la région de Jebel Chitana, Nefza, Jendouba (Tunisia).\n\n'
            'L\'application fonctionnera hors ligne avec ces données même '
            'si le backend est indisponible.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final hasData = _offlineStats?['hasData'] ?? false;
    final trails = _offlineStats?['trails'] as List? ?? [];
    final pois = _offlineStats?['pois'] as List? ?? [];
    final services = _offlineStats?['services'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            'Statistiques actuelles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow(
            Icons.route,
            'Sentiers',
            trails.length.toString(),
            hasData ? Colors.green : Colors.grey,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            Icons.place,
            'Points d\'intérêt',
            pois.length.toString(),
            hasData ? Colors.blue : Colors.grey,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            Icons.business,
            'Services locaux',
            services.length.toString(),
            hasData ? Colors.orange : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _loadSeedData,
            icon: const Icon(Icons.download),
            label: const Text('Charger les données de Jebel Chitana'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _clearAllData,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Supprimer toutes les données'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              side: BorderSide(color: AppTheme.errorColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info,
            color: Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(
                color: Colors.blue.shade900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
