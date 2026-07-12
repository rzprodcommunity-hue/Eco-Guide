import 'package:flutter/material.dart';

import '../services/map_offline_service.dart';

/// Manual offline-map download for the two covered regions (Tabarka + Jbel
/// Chitana), with a precision selector — same idea as the main Eco-Guide app.
class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  final MapOfflineService _service = MapOfflineService();

  OfflineTileMode _mode = OfflineTileMode.standard;
  bool _downloading = false;
  double _progress = 0;
  String _status = '';
  double _cachedMb = 0;

  static const _regions = <TileBounds>[
    TileBounds.tabarka,
    TileBounds.jbelChitana,
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _service.initialize();
    await _refreshSize();
  }

  Future<void> _refreshSize() async {
    final mb = await _service.getCachedTilesSizeMb();
    if (mounted) setState(() => _cachedMb = mb);
  }

  int get _estimatedMb {
    var total = 0;
    for (final r in _regions) {
      total += _service.estimateSizeMb(zooms: _mode.zooms, bounds: r);
    }
    return total;
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _status = 'Préparation…';
    });

    var totalDownloaded = 0;
    var totalFailed = 0;
    try {
      for (var i = 0; i < _regions.length; i++) {
        final region = _regions[i];
        final result = await _service.downloadTiles(
          bounds: region,
          zooms: _mode.zooms,
          onProgress: (progress, downloaded, total) {
            if (!mounted) return;
            setState(() {
              _progress = (i + progress) / _regions.length;
              _status = '${region.label}: $downloaded / $total';
            });
          },
        );
        totalDownloaded += result.downloaded;
        totalFailed += result.failed;
      }
      await _refreshSize();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Carte téléchargée ($totalDownloaded tuiles'
              '${totalFailed > 0 ? ', $totalFailed échouées' : ''}).',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur de téléchargement.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _progress = 0;
          _status = '';
        });
      }
    }
  }

  Future<void> _clear() async {
    await _service.clearTiles();
    await _refreshSize();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache carte supprimé.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte hors ligne'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Supprimer le cache',
            icon: const Icon(Icons.delete_outline),
            onPressed: _downloading ? null : _clear,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.map_outlined, size: 72, color: const Color(0xFF22B53A)),
          const SizedBox(height: 12),
          Text(
            'Régions : Tabarka + Jbel Chitana',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Cache actuel : ${_cachedMb.toStringAsFixed(1)} Mo',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          const Text('Précision', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: OfflineTileMode.values.map((mode) {
              final selected = _mode.id == mode.id;
              return ChoiceChip(
                label: Text(mode.label),
                selected: selected,
                selectedColor: const Color(0xFF22B53A),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: _downloading
                    ? null
                    : (_) => setState(() => _mode = mode),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF22B53A).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: const Color(0xFF22B53A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zoom max : ${_mode.maxZoom}  ·  ~$_estimatedMb Mo à télécharger',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          if (_downloading) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _status,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 6,
                color: const Color(0xFF22B53A),
                backgroundColor: const Color(0xFF22B53A).withValues(alpha: 0.15),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _downloading ? null : _download,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF22B53A),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.download),
            label: Text(
              _downloading
                  ? 'Téléchargement…'
                  : 'Télécharger la carte ($_estimatedMb Mo)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
