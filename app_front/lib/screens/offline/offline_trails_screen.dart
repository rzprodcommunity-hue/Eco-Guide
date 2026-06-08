import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/network_service.dart';
import '../../core/widgets/eco_page_header.dart';
import '../../models/local_service.dart';
import '../../models/poi.dart';
import '../../models/trail.dart';
import '../../providers/local_service_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/poi_provider.dart';
import '../../providers/trail_provider.dart';
import '../../services/api_client.dart';
import '../../services/map_offline_service.dart';
import '../../services/offline_cache_service.dart';
import '../../services/offline_service.dart';

class OfflineTrailsScreen extends StatefulWidget {
  const OfflineTrailsScreen({super.key});

  @override
  State<OfflineTrailsScreen> createState() => _OfflineTrailsScreenState();
}

class _OfflineTrailsScreenState extends State<OfflineTrailsScreen>
    with SingleTickerProviderStateMixin {
  static const _kInstalledTrailsKey = 'offline_installed_trails';
  static const _kInstalledPoisKey = 'offline_installed_pois';
  static const _kInstalledServicesKey = 'offline_installed_services';
  static const _kTileModeKey = 'offline_tile_mode';
  static const _kMapInstalledKey = 'offline_map_installed';

  static const _green = Color(0xFF22B53A);
  static const _greenDark = Color(0xFF1B8A2C);

  late final TabController _tabController;
  late final OfflineService _offlineService;
  late final MapOfflineService _mapOfflineService;

  bool _isLoading = false;
  OfflineTileMode _tileMode = OfflineTileMode.standard;
  bool _isMapInstalled = false;
  double _mapDownloadProgress = 0;
  String _mapDownloadStatus = '';
  bool _isDownloadingMap = false;
  double _cachedMapMb = 0;

  final Set<String> _installedTrailIds = <String>{};
  final Set<String> _installedPoiIds = <String>{};
  final Set<String> _installedServiceIds = <String>{};
  final Map<String, double> _itemProgress = <String, double>{};

  bool _isBulkDownloading = false;
  String _bulkStatus = '';

  String _trailQuery = '';
  String _poiQuery = '';
  String _serviceQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _offlineService = OfflineService(context.read<ApiClient>());
    _mapOfflineService = MapOfflineService();

    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    final trailProvider = context.read<TrailProvider>();
    final poiProvider = context.read<PoiProvider>();
    final localServiceProvider = context.read<LocalServiceProvider>();
    try {
      final isOnline = await NetworkService.hasInternetConnection();
      await Future.wait([
        trailProvider.loadTrails(
          refresh: true,
          forceOffline: !isOnline,
        ),
        poiProvider.loadPois(forceOffline: !isOnline),
        localServiceProvider.loadServices(
          forceOffline: !isOnline,
        ),
        _mapOfflineService.initialize(),
      ]);
      await _loadPersistedState();
      await _refreshCachedSizes();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();

    _installedTrailIds
      ..clear()
      ..addAll(prefs.getStringList(_kInstalledTrailsKey) ?? const <String>[]);
    _installedPoiIds
      ..clear()
      ..addAll(prefs.getStringList(_kInstalledPoisKey) ?? const <String>[]);
    _installedServiceIds
      ..clear()
      ..addAll(prefs.getStringList(_kInstalledServicesKey) ?? const <String>[]);

    // NOTE: the "downloaded" status reflects ONLY items the user explicitly
    // downloaded (tracked here in SharedPreferences). We deliberately do NOT
    // mark everything cached in SQLite for offline browsing as "downloaded".

    _tileMode = OfflineTileMode.fromId(prefs.getString(_kTileModeKey));
    _isMapInstalled = prefs.getBool(_kMapInstalledKey) ?? false;

    if (mounted) setState(() {});
  }

  Future<void> _refreshCachedSizes() async {
    final mb = await _mapOfflineService.getCachedTilesSizeMb();
    if (!mounted) return;
    setState(() => _cachedMapMb = mb);
  }

  Future<void> _persistTrails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kInstalledTrailsKey, _installedTrailIds.toList());
  }

  Future<void> _persistPois() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kInstalledPoisKey, _installedPoiIds.toList());
  }

  Future<void> _persistServices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kInstalledServicesKey,
      _installedServiceIds.toList(),
    );
  }

  Future<void> _persistTileMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTileModeKey, _tileMode.id);
  }

  Future<void> _persistMapInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMapInstalledKey, _isMapInstalled);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _requireOnline() async {
    final lp = context.read<LocaleProvider>();
    final isOnline = await NetworkService.hasInternetConnection();
    if (!isOnline) {
      _showMessage(lp.t('offline.internetRequired'));
    }
    return isOnline;
  }

  // ───── MAP TILES ──────────────────────────────────────────────────────────

  Future<void> _downloadMapTiles() async {
    final lp = context.read<LocaleProvider>();
    if (!await _requireOnline()) return;

    setState(() {
      _isDownloadingMap = true;
      _mapDownloadProgress = 0;
      _mapDownloadStatus = lp.t('offline.preparing');
    });

    try {
      // Download both covered regions together: Tabarka + Jbel Chitana (Nefza).
      const regions = <(String, TileBounds)>[
        ('Tabarka', TileBounds.tabarka),
        ('Jbel Chitana', TileBounds.jbelChitana),
      ];
      var totalDownloaded = 0;
      var totalCached = 0;
      var totalFailed = 0;

      for (var i = 0; i < regions.length; i++) {
        final region = regions[i];
        final result = await _mapOfflineService.downloadTiles(
          bounds: region.$2,
          zooms: _tileMode.zooms,
          onProgress: (progress, downloaded, total) {
            if (!mounted) return;
            setState(() {
              // Spread each region's progress across the full bar.
              _mapDownloadProgress = (i + progress) / regions.length;
              _mapDownloadStatus = '${region.$1}: $downloaded / $total';
            });
          },
        );
        totalDownloaded += result.downloaded;
        totalCached += result.alreadyCached;
        totalFailed += result.failed;
      }

      _isMapInstalled = true;
      await _persistMapInstalled();
      await _refreshCachedSizes();
      _showMessage(
        '${lp.t('offline.mapDownloaded')} '
        '(${totalDownloaded + totalCached} ${lp.t('offline.tiles')}, '
        '$totalFailed ${lp.t('offline.failed')}).',
      );
    } catch (e) {
      debugPrint('Map tile download error: $e');
      _showMessage(lp.t('offline.mapDownloadError'));
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingMap = false;
          _mapDownloadProgress = 0;
          _mapDownloadStatus = '';
        });
      }
    }
  }

  Future<void> _clearMapTiles() async {
    final lp = context.read<LocaleProvider>();
    setState(() => _isLoading = true);
    try {
      await _mapOfflineService.clearTabarkaTiles();
      _isMapInstalled = false;
      await _persistMapInstalled();
      await _refreshCachedSizes();
      _showMessage(lp.t('offline.mapTilesRemoved'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───── PER-ITEM DOWNLOADS ────────────────────────────────────────────────

  Future<void> _downloadTrail(Trail trail, {bool silent = false}) async {
    final poiProvider = context.read<PoiProvider>();
    final lp = context.read<LocaleProvider>();
    if (!await _requireOnline()) return;
    setState(() => _itemProgress['trail:${trail.id}'] = 0.05);

    try {
      // Cache hero images.
      if (trail.imageUrls != null) {
        for (final url in trail.imageUrls!) {
          try {
            await DefaultCacheManager().downloadFile(url);
          } catch (_) {}
        }
      }

      final pois = poiProvider.pois
          .where((p) => p.trailId == trail.id)
          .toList();

      // Tiles around the trail start.
      if (trail.startLatitude != null && trail.startLongitude != null) {
        final bounds = TileBounds.aroundPoint(
          trail.startLatitude!,
          trail.startLongitude!,
          radiusKm: 3,
        );
        await _mapOfflineService.downloadTiles(
          bounds: bounds,
          zooms: _tileMode.zooms,
          onProgress: (progress, _, _) {
            if (!mounted) return;
            setState(() => _itemProgress['trail:${trail.id}'] = progress);
          },
        );
      }

      await OfflineCacheService.instance.saveTrailPackage(
        trail: trail,
        pois: pois,
        quality: _tileMode.label,
        sizeMb: 0,
      );

      _installedTrailIds.add(trail.id);
      await _persistTrails();
      await _refreshCachedSizes();

      try {
        await _offlineService.markDownloaded(
          resourceType: 'trail',
          resourceId: trail.id,
          sizeBytes: 0,
        );
      } catch (_) {}

      if (!silent) {
        _showMessage(
          '${lp.t('offline.trailLabel')} "${trail.name}" ${lp.t('offline.saved')}',
        );
      }
    } catch (e) {
      debugPrint('Trail download error: $e');
      if (!silent) _showMessage(lp.t('offline.trailDownloadFailed'));
    } finally {
      if (mounted) {
        setState(() => _itemProgress.remove('trail:${trail.id}'));
      }
    }
  }

  Future<void> _removeTrail(Trail trail) async {
    final lp = context.read<LocaleProvider>();
    await OfflineCacheService.instance.removeTrailPackage(trail.id);
    _installedTrailIds.remove(trail.id);
    await _persistTrails();
    if (mounted) setState(() {});
    _showMessage(lp.t('offline.trailRemoved'));
  }

  Future<void> _downloadPoi(Poi poi, {bool silent = false}) async {
    final lp = context.read<LocaleProvider>();
    if (!await _requireOnline()) return;
    setState(() => _itemProgress['poi:${poi.id}'] = 0.1);

    try {
      if (poi.mediaUrl != null && poi.mediaUrl!.isNotEmpty) {
        try {
          await DefaultCacheManager().downloadFile(poi.mediaUrl!);
        } catch (_) {}
      }
      if (poi.additionalMediaUrls != null) {
        for (final url in poi.additionalMediaUrls!) {
          try {
            await DefaultCacheManager().downloadFile(url);
          } catch (_) {}
        }
      }

      await OfflineCacheService.instance.savePoi(poi);
      _installedPoiIds.add(poi.id);
      await _persistPois();

      try {
        await _offlineService.markDownloaded(
          resourceType: 'poi',
          resourceId: poi.id,
          sizeBytes: 0,
        );
      } catch (_) {}

      if (!silent) {
        _showMessage('POI "${poi.name}" ${lp.t('offline.saved')}');
      }
    } catch (e) {
      debugPrint('POI download error: $e');
      if (!silent) _showMessage(lp.t('offline.poiDownloadFailed'));
    } finally {
      if (mounted) setState(() => _itemProgress.remove('poi:${poi.id}'));
    }
  }

  Future<void> _removePoi(Poi poi) async {
    final lp = context.read<LocaleProvider>();
    await OfflineCacheService.instance.removePoi(poi.id);
    _installedPoiIds.remove(poi.id);
    await _persistPois();
    if (mounted) setState(() {});
    _showMessage(lp.t('offline.poiRemoved'));
  }

  Future<void> _downloadService(LocalService service, {bool silent = false}) async {
    final lp = context.read<LocaleProvider>();
    if (!await _requireOnline()) return;
    setState(() => _itemProgress['service:${service.id}'] = 0.1);

    try {
      if (service.imageUrl != null && service.imageUrl!.isNotEmpty) {
        try {
          await DefaultCacheManager().downloadFile(service.imageUrl!);
        } catch (_) {}
      }
      if (service.additionalImages != null) {
        for (final url in service.additionalImages!) {
          try {
            await DefaultCacheManager().downloadFile(url);
          } catch (_) {}
        }
      }

      await OfflineCacheService.instance.saveLocalService(service);
      _installedServiceIds.add(service.id);
      await _persistServices();

      try {
        await _offlineService.markDownloaded(
          resourceType: 'service',
          resourceId: service.id,
          sizeBytes: 0,
        );
      } catch (_) {}

      if (!silent) {
        _showMessage(
          '${lp.t('offline.serviceLabel')} "${service.name}" ${lp.t('offline.saved')}',
        );
      }
    } catch (e) {
      debugPrint('Service download error: $e');
      if (!silent) _showMessage(lp.t('offline.serviceDownloadFailed'));
    } finally {
      if (mounted) {
        setState(() => _itemProgress.remove('service:${service.id}'));
      }
    }
  }

  Future<void> _removeService(LocalService service) async {
    final lp = context.read<LocaleProvider>();
    await OfflineCacheService.instance.removeLocalService(service.id);
    _installedServiceIds.remove(service.id);
    await _persistServices();
    if (mounted) setState(() {});
    _showMessage(lp.t('offline.serviceRemoved'));
  }

  // ───── BULK DOWNLOADS ────────────────────────────────────────────────────

  Future<void> _bulkDownloadTrails() async {
    if (_isBulkDownloading) return;
    final lp = context.read<LocaleProvider>();
    final trails = context.read<TrailProvider>().trails;
    if (!await _requireOnline()) return;

    final pending = trails.where((t) => !_installedTrailIds.contains(t.id)).toList();
    if (pending.isEmpty) {
      _showMessage(lp.t('offline.allTrailsDownloaded'));
      return;
    }

    setState(() {
      _isBulkDownloading = true;
      _bulkStatus = '${lp.t('offline.trailsTab')} 0 / ${pending.length}';
    });

    for (var i = 0; i < pending.length; i++) {
      if (!mounted) break;
      setState(() =>
          _bulkStatus = '${lp.t('offline.trailsTab')} ${i + 1} / ${pending.length}');
      await _downloadTrail(pending[i], silent: true);
    }

    if (mounted) {
      setState(() {
        _isBulkDownloading = false;
        _bulkStatus = '';
      });
      _showMessage(
        '${pending.length} ${lp.t('offline.trailsDownloadedCount')}',
      );
    }
  }

  Future<void> _bulkDownloadPois() async {
    if (_isBulkDownloading) return;
    final lp = context.read<LocaleProvider>();
    final pois = context.read<PoiProvider>().pois;
    if (!await _requireOnline()) return;

    final pending = pois.where((p) => !_installedPoiIds.contains(p.id)).toList();
    if (pending.isEmpty) {
      _showMessage(lp.t('offline.allPoisDownloaded'));
      return;
    }

    setState(() {
      _isBulkDownloading = true;
      _bulkStatus = 'POIs 0 / ${pending.length}';
    });

    for (var i = 0; i < pending.length; i++) {
      if (!mounted) break;
      setState(() => _bulkStatus = 'POIs ${i + 1} / ${pending.length}');
      await _downloadPoi(pending[i], silent: true);
    }

    if (mounted) {
      setState(() {
        _isBulkDownloading = false;
        _bulkStatus = '';
      });
      _showMessage(
        '${pending.length} ${lp.t('offline.poisDownloadedCount')}',
      );
    }
  }

  /// Downloads OR updates EVERYTHING in one pass: every trail, every POI and
  /// every service. Re-downloading an already-installed item refreshes its
  /// cached data, so this doubles as a "mettre à jour" action.
  Future<void> _bulkDownloadAll() async {
    if (_isBulkDownloading) return;
    final lp = context.read<LocaleProvider>();
    final trails = context.read<TrailProvider>().trails;
    final pois = context.read<PoiProvider>().pois;
    final services = context.read<LocalServiceProvider>().services;
    if (!await _requireOnline()) return;

    final total = trails.length + pois.length + services.length;
    if (total == 0) {
      _showMessage(lp.t('offline.noDataToDownload'));
      return;
    }

    setState(() {
      _isBulkDownloading = true;
      _bulkStatus = '${lp.t('offline.preparing')} 0 / $total';
    });

    var done = 0;
    void tick(String label) {
      if (!mounted) return;
      setState(() => _bulkStatus = '$label ${done + 1} / $total');
    }

    for (final trail in trails) {
      if (!mounted) break;
      tick(lp.t('offline.trailsTab'));
      await _downloadTrail(trail, silent: true);
      done++;
    }
    for (final poi in pois) {
      if (!mounted) break;
      tick('POIs');
      await _downloadPoi(poi, silent: true);
      done++;
    }
    for (final service in services) {
      if (!mounted) break;
      tick(lp.t('offline.servicesTab'));
      await _downloadService(service, silent: true);
      done++;
    }

    if (mounted) {
      setState(() {
        _isBulkDownloading = false;
        _bulkStatus = '';
      });
      _showMessage(
        '$total ${lp.t('offline.itemsDownloadedUpdated')}',
      );
    }
  }

  Future<void> _bulkDownloadServices() async {
    if (_isBulkDownloading) return;
    final lp = context.read<LocaleProvider>();
    final services = context.read<LocalServiceProvider>().services;
    if (!await _requireOnline()) return;

    final pending =
        services.where((s) => !_installedServiceIds.contains(s.id)).toList();
    if (pending.isEmpty) {
      _showMessage(lp.t('offline.allServicesDownloaded'));
      return;
    }

    setState(() {
      _isBulkDownloading = true;
      _bulkStatus = '${lp.t('offline.servicesTab')} 0 / ${pending.length}';
    });

    for (var i = 0; i < pending.length; i++) {
      if (!mounted) break;
      setState(() => _bulkStatus =
          '${lp.t('offline.servicesTab')} ${i + 1} / ${pending.length}');
      await _downloadService(pending[i], silent: true);
    }

    if (mounted) {
      setState(() {
        _isBulkDownloading = false;
        _bulkStatus = '';
      });
      _showMessage(
        '${pending.length} ${lp.t('offline.servicesDownloadedCount')}',
      );
    }
  }

  // ───── BUILD ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocaleProvider>();
    // Estimate covers both downloaded regions: Tabarka + Jbel Chitana (Nefza).
    final estimatedMapMb = _mapOfflineService.estimateSizeMb(
          zooms: _tileMode.zooms,
          bounds: TileBounds.tabarka,
        ) +
        _mapOfflineService.estimateSizeMb(
          zooms: _tileMode.zooms,
          bounds: TileBounds.jbelChitana,
        );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: EcoPageHeader(title: lp.t('offline.title')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: _green,
              onRefresh: _initialize,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  _buildHeroCard(estimatedMapMb),
                  const SizedBox(height: 16),
                  _buildMapDownloadCard(estimatedMapMb),
                  const SizedBox(height: 16),
                  _buildDownloadAllCard(),
                  const SizedBox(height: 16),
                  _buildTabsCard(),
                  const SizedBox(height: 14),
                  Text(
                    '${lp.t('offline.dataSources')}: OpenStreetMap + Eco-Guide',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard(int estimatedMapMb) {
    final lp = context.watch<LocaleProvider>();
    final totalItems = _installedTrailIds.length +
        _installedPoiIds.length +
        _installedServiceIds.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_greenDark, _green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lp.t('offline.heroTitle'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _tileMode.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lp.t('offline.heroSubtitle'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroStat(
                value: '${_cachedMapMb.toStringAsFixed(0)} ${lp.t('offline.mb')}',
                label: lp.t('offline.statMap'),
              ),
              _heroStat(value: '$totalItems', label: lp.t('offline.statItems')),
              _heroStat(
                value:
                    '${(estimatedMapMb / 1).toStringAsFixed(0)} ${lp.t('offline.mb')}',
                label: lp.t('offline.statToPlan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat({required String value, required String label}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadAllCard() {
    final lp = context.watch<LocaleProvider>();
    final trails = context.watch<TrailProvider>().trails;
    final pois = context.watch<PoiProvider>().pois;
    final services = context.watch<LocalServiceProvider>().services;

    final total = trails.length + pois.length + services.length;
    final installed = trails.where((t) => _installedTrailIds.contains(t.id)).length +
        pois.where((p) => _installedPoiIds.contains(p.id)).length +
        services.where((s) => _installedServiceIds.contains(s.id)).length;
    final allInstalled = total > 0 && installed >= total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_sync, color: _green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lp.t('offline.allContent'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lp.t('offline.allContentSubtitle'),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$installed / $total',
                  style: const TextStyle(
                    color: _greenDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniCount(
                  Icons.terrain, '${trails.length} ${lp.t('offline.trailsTab')}'),
              _miniCount(Icons.place, '${pois.length} POIs'),
              _miniCount(Icons.storefront,
                  '${services.length} ${lp.t('offline.servicesTab')}'),
            ],
          ),
          if (_isBulkDownloading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_green),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _bulkStatus,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _greenDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _isBulkDownloading || total == 0 ? null : _bulkDownloadAll,
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                allInstalled ? Icons.refresh : Icons.download_for_offline,
              ),
              label: Text(
                total == 0
                    ? lp.t('offline.noData')
                    : allInstalled
                        ? '${lp.t('offline.updateAll')} ($total)'
                        : '${lp.t('offline.downloadAll')} ($total)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniCount(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _greenDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: _greenDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapDownloadCard(int estimatedMapMb) {
    final lp = context.watch<LocaleProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.map_outlined, color: _green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${lp.t('offline.mapCardTitle')} ${TabarkaMapBounds.label}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isMapInstalled
                          ? '${lp.t('offline.cache')}: ${_cachedMapMb.toStringAsFixed(1)} ${lp.t('offline.mb')} · ${lp.t('offline.tabarkaZone')}'
                          : lp.t('offline.tabarkaCoastOffline'),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isMapInstalled)
                IconButton(
                  tooltip: lp.t('offline.deleteMapCache'),
                  onPressed: _isDownloadingMap ? null : _clearMapTiles,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red[400],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            lp.t('offline.detailLevel'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: OfflineTileMode.values.map((mode) {
              final selected = _tileMode.id == mode.id;
              return ChoiceChip(
                label: Text(mode.label),
                selected: selected,
                selectedColor: _green,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                onSelected: _isDownloadingMap
                    ? null
                    : (_) async {
                        setState(() => _tileMode = mode);
                        await _persistTileMode();
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: _greenDark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${lp.t('offline.maxZoom')}: ${_tileMode.maxZoom}  ·  ~$estimatedMapMb ${lp.t('offline.mb')} ${lp.t('offline.toDownload')}',
                    style: const TextStyle(fontSize: 11, color: _greenDark),
                  ),
                ),
              ],
            ),
          ),
          if (_isDownloadingMap) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _mapDownloadStatus,
                  style: const TextStyle(fontSize: 12, color: _greenDark),
                ),
                Text(
                  '${(_mapDownloadProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _greenDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _mapDownloadProgress,
                minHeight: 6,
                backgroundColor: _green.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(_green),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isDownloadingMap ? null : _downloadMapTiles,
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                _isMapInstalled ? Icons.refresh : Icons.download,
              ),
              label: Text(
                _isMapInstalled
                    ? '${lp.t('offline.updateMap')} ($estimatedMapMb ${lp.t('offline.mb')})'
                    : '${lp.t('offline.downloadMap')} ($estimatedMapMb ${lp.t('offline.mb')})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsCard() {
    final lp = context.watch<LocaleProvider>();
    final trails = context.watch<TrailProvider>().trails;
    final pois = context.watch<PoiProvider>().pois;
    final services = context.watch<LocalServiceProvider>().services;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          if (_isBulkDownloading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.07),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_green),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${lp.t('offline.downloading')}: $_bulkStatus',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _greenDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          TabBar(
            controller: _tabController,
            labelColor: _greenDark,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: _green,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            tabs: [
              Tab(
                icon: const Icon(Icons.terrain, size: 18),
                text: '${lp.t('offline.trailsTab')} (${trails.length})',
              ),
              Tab(
                icon: const Icon(Icons.place, size: 18),
                text: 'POIs (${pois.length})',
              ),
              Tab(
                icon: const Icon(Icons.storefront, size: 18),
                text: '${lp.t('offline.servicesTab')} (${services.length})',
              ),
            ],
          ),
          SizedBox(
            height: 480,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTrailsList(trails),
                _buildPoisList(pois),
                _buildServicesList(services),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar({
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, size: 20),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildBulkBar({
    required String label,
    required int pending,
    required VoidCallback onPressed,
  }) {
    final lp = context.watch<LocaleProvider>();
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: _isBulkDownloading || pending == 0 ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: _green.withValues(alpha: 0.12),
              foregroundColor: _greenDark,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.download_for_offline, size: 18),
            label: Text(
              pending == 0
                  ? lp.t('offline.allDownloaded')
                  : '${lp.t('offline.downloadAll')} ($pending)',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrailsList(List<Trail> trails) {
    final lp = context.watch<LocaleProvider>();
    final filtered = trails.where((t) {
      if (_trailQuery.isEmpty) return true;
      return t.name.toLowerCase().contains(_trailQuery.toLowerCase());
    }).toList();
    final pending =
        trails.where((t) => !_installedTrailIds.contains(t.id)).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          _buildSearchBar(
            hint: lp.t('offline.searchTrail'),
            value: _trailQuery,
            onChanged: (v) => setState(() => _trailQuery = v),
          ),
          const SizedBox(height: 10),
          _buildBulkBar(
            label: 'sentier(s)',
            pending: pending,
            onPressed: _bulkDownloadTrails,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: filtered.isEmpty
                ? _emptyState(lp.t('offline.noTrails'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _buildTrailTile(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailTile(Trail trail) {
    final installed = _installedTrailIds.contains(trail.id);
    final progress = _itemProgress['trail:${trail.id}'];
    final downloading = progress != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: installed
              ? _green.withValues(alpha: 0.4)
              : Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.hiking, color: _green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trail.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${trail.distanceText} · ${trail.difficulty}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
                if (downloading) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: _green.withValues(alpha: 0.15),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_green),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _actionButton(
            installed: installed,
            downloading: downloading,
            onDownload: () => _downloadTrail(trail),
            onRemove: () => _removeTrail(trail),
          ),
        ],
      ),
    );
  }

  Widget _buildPoisList(List<Poi> pois) {
    final lp = context.watch<LocaleProvider>();
    final filtered = pois.where((p) {
      if (_poiQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_poiQuery.toLowerCase());
    }).toList();
    final pending = pois.where((p) => !_installedPoiIds.contains(p.id)).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          _buildSearchBar(
            hint: lp.t('offline.searchPoi'),
            value: _poiQuery,
            onChanged: (v) => setState(() => _poiQuery = v),
          ),
          const SizedBox(height: 10),
          _buildBulkBar(
            label: 'POI(s)',
            pending: pending,
            onPressed: _bulkDownloadPois,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: filtered.isEmpty
                ? _emptyState(lp.t('offline.noPois'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _buildPoiTile(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoiTile(Poi poi) {
    final installed = _installedPoiIds.contains(poi.id);
    final progress = _itemProgress['poi:${poi.id}'];
    final downloading = progress != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: installed
              ? _green.withValues(alpha: 0.4)
              : Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.place, color: Colors.black87),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poi.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  poi.typeDisplayName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
                if (downloading) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: _green.withValues(alpha: 0.15),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_green),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _actionButton(
            installed: installed,
            downloading: downloading,
            onDownload: () => _downloadPoi(poi),
            onRemove: () => _removePoi(poi),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList(List<LocalService> services) {
    final lp = context.watch<LocaleProvider>();
    final filtered = services.where((s) {
      if (_serviceQuery.isEmpty) return true;
      return s.name.toLowerCase().contains(_serviceQuery.toLowerCase());
    }).toList();
    final pending =
        services.where((s) => !_installedServiceIds.contains(s.id)).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          _buildSearchBar(
            hint: lp.t('offline.searchService'),
            value: _serviceQuery,
            onChanged: (v) => setState(() => _serviceQuery = v),
          ),
          const SizedBox(height: 10),
          _buildBulkBar(
            label: 'service(s)',
            pending: pending,
            onPressed: _bulkDownloadServices,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: filtered.isEmpty
                ? _emptyState(lp.t('offline.noServices'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _buildServiceTile(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTile(LocalService service) {
    final installed = _installedServiceIds.contains(service.id);
    final progress = _itemProgress['service:${service.id}'];
    final downloading = progress != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: installed
              ? _green.withValues(alpha: 0.4)
              : Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1E9A35).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront, color: Color(0xFF1E9A35)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  service.categoryDisplayName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
                if (downloading) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: _green.withValues(alpha: 0.15),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_green),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _actionButton(
            installed: installed,
            downloading: downloading,
            onDownload: () => _downloadService(service),
            onRemove: () => _removeService(service),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required bool installed,
    required bool downloading,
    required VoidCallback onDownload,
    required VoidCallback onRemove,
  }) {
    final lp = context.watch<LocaleProvider>();
    if (downloading) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(_green),
        ),
      );
    }
    if (installed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: _green, size: 20),
          const SizedBox(width: 4),
          Text(
            lp.t('offline.downloaded'),
            style: const TextStyle(
              color: _green,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Colors.red[400],
            onPressed: onRemove,
            tooltip: lp.t('offline.remove'),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          lp.t('offline.notDownloaded'),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          onPressed: onDownload,
          icon: const Icon(Icons.download_rounded, color: _green, size: 26),
          tooltip: lp.t('offline.download'),
        ),
      ],
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

}
