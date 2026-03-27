import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/eco_page_header.dart';
import '../../models/trail.dart';
import '../../providers/local_service_provider.dart';
import '../../providers/poi_provider.dart';
import '../../providers/trail_provider.dart';
import '../../services/api_client.dart';
import '../../services/offline_cache_service.dart';
import '../../services/map_offline_service.dart';
import '../../services/offline_service.dart';

class OfflineTrailsScreen extends StatefulWidget {
  const OfflineTrailsScreen({super.key});

  @override
  State<OfflineTrailsScreen> createState() => _OfflineTrailsScreenState();
}

class _OfflineTrailsScreenState extends State<OfflineTrailsScreen> {
  static const Map<String, double> _resolutionFactor = {
    'Basse': 0.7,
    'Moyenne': 1.0,
    'Haute': 1.45,
  };

  static const Map<String, int> _basePackageMb = {
    'topo': 450,
    'poi_flora': 120,
    'services': 45,
  };

  late final OfflineService _offlineService;
  late final MapOfflineService _mapOfflineService;

  bool _isLoading = false;
  bool _autoSync = true;
  String _resolution = 'Moyenne';
  double _deviceStorageGb = 128;
  double _usedStorageGb = 0;

  List<Trail> _allTrails = [];
  List<Trail> _regionTrails = [];
  final Set<String> _installedPackages = <String>{};

  @override
  void initState() {
    super.initState();
    _offlineService = OfflineService(context.read<ApiClient>());
    _mapOfflineService = MapOfflineService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        context.read<TrailProvider>().loadTrails(refresh: true),
        context.read<PoiProvider>().loadPois(),
        context.read<LocalServiceProvider>().loadServices(),
        _mapOfflineService.initialize(),
      ]);

      _allTrails = context.read<TrailProvider>().trails;
      _regionTrails = _resolveTabarkaRegion(_allTrails);

      await _loadPersistedState();
      await _refreshStorageUsage();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Trail> _resolveTabarkaRegion(List<Trail> trails) {
    final tabarka = trails
        .where(
          (trail) => (trail.region ?? '').toLowerCase().contains('tabarka'),
        )
        .toList();
    if (tabarka.isNotEmpty) return tabarka;

    final grouped = <String, List<Trail>>{};
    for (final trail in trails) {
      final region = (trail.region ?? 'Region principale').trim();
      grouped.putIfAbsent(region, () => <Trail>[]).add(trail);
    }

    if (grouped.isEmpty) return <Trail>[];
    final largestRegion = grouped.entries.reduce(
      (a, b) => a.value.length >= b.value.length ? a : b,
    );
    return largestRegion.value;
  }

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final stored =
        prefs.getStringList('offline_installed_packages') ?? <String>[];
    final autoSync = prefs.getBool('offline_auto_sync') ?? true;
    final selectedResolution =
        prefs.getString('offline_resolution') ?? 'Moyenne';

    if (!mounted) return;
    setState(() {
      _installedPackages
        ..clear()
        ..addAll(stored);
      _autoSync = autoSync;
      _resolution = _resolutionFactor.containsKey(selectedResolution)
          ? selectedResolution
          : 'Moyenne';
    });
  }

  Future<void> _persistInstalledPackages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'offline_installed_packages',
      _installedPackages.toList(),
    );
  }

  Future<void> _persistResolution() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('offline_resolution', _resolution);
  }

  Future<void> _persistAutoSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_auto_sync', _autoSync);
  }

  Future<void> _refreshStorageUsage() async {
    final offlineUsedMb = await OfflineCacheService.instance.getTotalUsageMb();
    if (!mounted) return;
    setState(() {
      _usedStorageGb = (offlineUsedMb / 1024).clamp(0, _deviceStorageGb);
    });
  }

  int _packageSizeMb(String packageId) {
    final base = _basePackageMb[packageId] ?? 50;
    final factor = _resolutionFactor[_resolution] ?? 1.0;
    return (base * factor).round();
  }

  int _totalDownloadSizeMb() {
    return _basePackageMb.keys
        .where((id) => !_installedPackages.contains(id))
        .map(_packageSizeMb)
        .fold(0, (a, b) => a + b);
  }

  int _installedSizeMb() {
    return _installedPackages.map(_packageSizeMb).fold(0, (a, b) => a + b);
  }

  Future<void> _installPackage(String packageId) async {
    if (_regionTrails.isEmpty) {
      _showMessage(
        'Aucune donnee regionale disponible pour le telechargement.',
      );
      return;
    }

    setState(() => _isLoading = true);
    final packageSizeMb = _packageSizeMb(packageId);

    try {
      final poiProvider = context.read<PoiProvider>();
      final localServiceProvider = context.read<LocalServiceProvider>();
      final regionTrailIds = _regionTrails.map((trail) => trail.id).toSet();
      final regionPois = poiProvider.pois
          .where(
            (poi) =>
                poi.trailId != null && regionTrailIds.contains(poi.trailId),
          )
          .toList();

      final bytesPerTrail =
          ((packageSizeMb * 1024 * 1024) / _regionTrails.length).round();

      if (packageId == 'topo') {
        final mapResult = await _mapOfflineService.downloadTabarkaTiles();

        for (final trail in _regionTrails) {
          await OfflineCacheService.instance.saveTrailPackage(
            trail: trail,
            pois: regionPois.where((poi) => poi.trailId == trail.id).toList(),
            quality: _resolution,
            sizeMb: packageSizeMb / _regionTrails.length,
          );

          await _offlineService.markDownloaded(
            resourceType: 'trail',
            resourceId: trail.id,
            sizeBytes: bytesPerTrail,
          );
        }

        if (mapResult.failed > 0 && mounted) {
          _showMessage(
            'Carte Tabarka: ${mapResult.downloaded} tuiles telechargees, ${mapResult.failed} en echec.',
          );
        }
      } else if (packageId == 'poi_flora') {
        await OfflineCacheService.instance.savePois(regionPois);

        final representativeTrail = _regionTrails.first;
        await _offlineService.markDownloaded(
          resourceType: 'poi',
          resourceId: regionPois.isNotEmpty
              ? regionPois.first.id
              : representativeTrail.id,
          sizeBytes: packageSizeMb * 1024 * 1024,
        );
      } else {
        if (localServiceProvider.services.isEmpty) {
          await localServiceProvider.loadServices();
        }
        await OfflineCacheService.instance.saveLocalServices(
          localServiceProvider.services,
        );

        final representativeTrail = _regionTrails.first;
        await _offlineService.markDownloaded(
          resourceType: 'service',
          resourceId: representativeTrail.id,
          sizeBytes: packageSizeMb * 1024 * 1024,
        );
      }

      _installedPackages.add(packageId);
      await _persistInstalledPackages();
      await _refreshStorageUsage();
      _showMessage('Package installe avec succes (${packageSizeMb} Mo).');
    } catch (e) {
      debugPrint('Installation error: $e');
      final errorMsg = e.toString();
      _showMessage(
        errorMsg.contains('ApiException')
            ? 'Erreur backend: ${errorMsg.split('-').last.trim()}'
            : 'Echec du telechargement. Verifiez la connexion backend.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removePackage(String packageId) async {
    setState(() => _isLoading = true);

    try {
      if (packageId == 'topo') {
        await _mapOfflineService.clearTabarkaTiles();
        for (final trail in _regionTrails) {
          await OfflineCacheService.instance.removeTrailPackage(trail.id);
        }
      } else if (packageId == 'services') {
        await OfflineCacheService.instance.clearOfflineLocalServices();
      }

      _installedPackages.remove(packageId);
      await _persistInstalledPackages();
      await _refreshStorageUsage();
      _showMessage('Package supprime.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _installAllPackages() async {
    final pending = _basePackageMb.keys
        .where((id) => !_installedPackages.contains(id))
        .toList();

    for (final packageId in pending) {
      await _installPackage(packageId);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final storageRatio = (_usedStorageGb / _deviceStorageGb).clamp(0.0, 1.0);
    final freeGb = (_deviceStorageGb - _usedStorageGb).clamp(
      0.0,
      _deviceStorageGb,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F3),
      appBar: EcoPageHeader(
        title: 'Mode Hors Ligne',
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _initialize,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStorageCard(storageRatio, freeGb),
                const SizedBox(height: 18),
                _buildRegionTitle(),
                const SizedBox(height: 12),
                _buildPackageCard(
                  id: 'topo',
                  title: 'Cartographie topographique',
                  subtitle:
                      'Relief HD et traces des sentiers de la region selectionnee.',
                  icon: Icons.map,
                ),
                const SizedBox(height: 12),
                _buildPackageCard(
                  id: 'poi_flora',
                  title: 'Points d\'interet & Flore',
                  subtitle:
                      'Guide multimedia des points cles et plantes locales.',
                  icon: Icons.park,
                ),
                const SizedBox(height: 12),
                _buildPackageCard(
                  id: 'services',
                  title: 'Annuaire des Services',
                  subtitle: 'Refuges, secours et services d\'urgence proches.',
                  icon: Icons.cabin,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed:
                      _basePackageMb.keys.any(
                        (id) => !_installedPackages.contains(id),
                      )
                      ? _installAllPackages
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3FAE4E),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.download),
                  label: Text(
                    'Tout telecharger (${_totalDownloadSizeMb()} Mo)',
                  ),
                ),
                const SizedBox(height: 16),
                _buildAutoSyncCard(),
                const SizedBox(height: 12),
                Text(
                  'Donnees fournies par OpenStreetMap + Eco-Guide',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ],
            ),
    );
  }

  Widget _buildStorageCard(double storageRatio, double freeGb) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1212),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Stockage de l\'appareil',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_usedStorageGb.toStringAsFixed(1)} Go utilises / ${_deviceStorageGb.toStringAsFixed(0)} Go',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: storageRatio,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF39C85A),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStorageMetric(
                '${(_usedStorageGb * 1024).toStringAsFixed(0)} Mo',
                'Apps',
              ),
              _buildStorageMetric('${_installedSizeMb()} Mo', 'Cartes & POI'),
              _buildStorageMetric(
                '${freeGb.toStringAsFixed(1)} Go',
                'Espace libre',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageMetric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildRegionTitle() {
    final regionLabel = _regionTrails.isEmpty
        ? 'Region indisponible'
        : (_regionTrails.first.region ?? 'Tabarka');

    return Text(
      'Telechargement complet du parc - $regionLabel',
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Color(0xFF141A1A),
      ),
    );
  }

  Widget _buildPackageCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isInstalled = _installedPackages.contains(id);
    final sizeMb = _packageSizeMb(id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4ECE4)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2E8A3F)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF18201D),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '$sizeMb Mo - ${isInstalled ? 'Pret' : 'Non installe'}',
                  style: TextStyle(
                    color: isInstalled
                        ? const Color(0xFF2E8A3F)
                        : Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: _isLoading ? null : () => _installPackage(id),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF39B653),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(130, 34),
                ),
                child: Text(
                  isInstalled ? 'Mise a jour' : 'Telecharger',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: isInstalled && !_isLoading
                    ? () => _removePackage(id)
                    : null,
                child: const Text('Retirer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoSyncCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FCF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0ECE0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync, color: Color(0xFF2E8A3F)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Synchronisation Automatique',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Mettre a jour les donnees via Wi-Fi.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _autoSync,
            onChanged: (value) async {
              setState(() => _autoSync = value);
              await _persistAutoSync();
            },
            activeColor: const Color(0xFF2EA043),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _resolution,
            borderRadius: BorderRadius.circular(12),
            underline: const SizedBox.shrink(),
            items: _resolutionFactor.keys
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _resolution = value);
              await _persistResolution();
            },
          ),
        ],
      ),
    );
  }
}
