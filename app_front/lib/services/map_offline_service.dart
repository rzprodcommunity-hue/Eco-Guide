import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TabarkaMapBounds {
  static const double minLat = 36.9000;
  static const double maxLat = 37.0500;
  static const double minLng = 8.7000;
  static const double maxLng = 8.8500;

  static const String label = 'Tabarka';
}

/// Bounding box autour du massif du Jbel Chitana (Mogods, Tunisie).
/// Pic ~ 37.083° N, 9.066° E. La boîte couvre tout le massif sur ~15 km.
class JbelChitanaMapBounds {
  static const double minLat = 37.0000;
  static const double maxLat = 37.1500;
  static const double minLng = 8.9500;
  static const double maxLng = 9.1500;

  static const String label = 'Jbel Chitana';
}

/// Tile zoom presets that match the UX "mode" selector on the offline screen.
/// - eco        : low storage, basic overview
/// - standard   : balanced
/// - detailed   : great for hiking detail
/// - max        : maximum detail, biggest download
class OfflineTileMode {
  final String id;
  final String label;
  final List<int> zooms;
  final int maxZoom;

  const OfflineTileMode({
    required this.id,
    required this.label,
    required this.zooms,
    required this.maxZoom,
  });

  static const OfflineTileMode eco = OfflineTileMode(
    id: 'eco',
    label: 'Eco',
    zooms: [10, 11, 12, 13],
    maxZoom: 13,
  );

  static const OfflineTileMode standard = OfflineTileMode(
    id: 'standard',
    label: 'Standard',
    zooms: [10, 11, 12, 13, 14, 15],
    maxZoom: 15,
  );

  static const OfflineTileMode detailed = OfflineTileMode(
    id: 'detailed',
    label: 'Détaillé',
    zooms: [10, 11, 12, 13, 14, 15, 16, 17],
    maxZoom: 17,
  );

  static const OfflineTileMode max = OfflineTileMode(
    id: 'max',
    label: 'Max (zoom + détails)',
    zooms: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    maxZoom: 19,
  );

  static const List<OfflineTileMode> values = [eco, standard, detailed, max];

  static OfflineTileMode fromId(String? id) {
    return values.firstWhere(
      (m) => m.id == id,
      orElse: () => standard,
    );
  }
}

class MapOfflineDownloadResult {
  final int downloaded;
  final int alreadyCached;
  final int failed;

  const MapOfflineDownloadResult({
    required this.downloaded,
    required this.alreadyCached,
    required this.failed,
  });

  int get totalProcessed => downloaded + alreadyCached + failed;
}

class TileBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const TileBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  static const TileBounds tabarka = TileBounds(
    minLat: TabarkaMapBounds.minLat,
    maxLat: TabarkaMapBounds.maxLat,
    minLng: TabarkaMapBounds.minLng,
    maxLng: TabarkaMapBounds.maxLng,
  );

  static const TileBounds jbelChitana = TileBounds(
    minLat: JbelChitanaMapBounds.minLat,
    maxLat: JbelChitanaMapBounds.maxLat,
    minLng: JbelChitanaMapBounds.minLng,
    maxLng: JbelChitanaMapBounds.maxLng,
  );

  /// Build a small bounding box around a (lat, lng) point.
  /// [radiusKm] is the half-edge of the square in kilometers.
  factory TileBounds.aroundPoint(
    double lat,
    double lng, {
    double radiusKm = 2.0,
  }) {
    const double kmPerDegLat = 111.0;
    final double kmPerDegLng = 111.0 * math.cos(lat * math.pi / 180.0);
    final double dLat = radiusKm / kmPerDegLat;
    final double dLng = radiusKm / (kmPerDegLng <= 0 ? 1.0 : kmPerDegLng);
    return TileBounds(
      minLat: lat - dLat,
      maxLat: lat + dLat,
      minLng: lng - dLng,
      maxLng: lng + dLng,
    );
  }
}

class MapOfflineService {
  MapOfflineService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const String standardTileUrlTemplate =
      'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
  static const String _tileUrlTemplate = standardTileUrlTemplate;

  final http.Client _httpClient;
  static String? _sharedBaseTilePath;
  String? _baseTilePath;

  Future<void> initialize() async {
    final baseDir = await _baseTileDirectory();
    _baseTilePath = baseDir.path;
    _sharedBaseTilePath = baseDir.path;
  }

  Future<Directory> _baseTileDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'offline_tiles', 'tabarka'));
  }

  Future<File> tileFile({
    required int z,
    required int x,
    required int y,
  }) async {
    final baseDir = await _baseTileDirectory();
    return File(p.join(baseDir.path, '$z', '$x', '$y.png'));
  }

  File? tileFileSync({required int z, required int x, required int y}) {
    final base = _baseTilePath ?? _sharedBaseTilePath;
    if (base == null) return null;

    final candidate = File(p.join(base, '$z', '$x', '$y.png'));
    if (candidate.existsSync()) return candidate;
    return null;
  }

  String tileUrl({required int z, required int x, required int y}) {
    return _tileUrlTemplate
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
  }

  int estimateTileCount({
    List<int> zooms = const [11, 12, 13, 14, 15],
    TileBounds bounds = TileBounds.tabarka,
  }) {
    var total = 0;
    for (final z in zooms) {
      final xMin = _lonToTileX(bounds.minLng, z);
      final xMax = _lonToTileX(bounds.maxLng, z);
      final yMin = _latToTileY(bounds.maxLat, z);
      final yMax = _latToTileY(bounds.minLat, z);
      total += (xMax - xMin + 1) * (yMax - yMin + 1);
    }
    return total;
  }

  /// Rough estimate, ~25 KB / tile on Google "m" layer.
  int estimateSizeMb({
    required List<int> zooms,
    TileBounds bounds = TileBounds.tabarka,
  }) {
    final tiles = estimateTileCount(zooms: zooms, bounds: bounds);
    final bytes = tiles * 25 * 1024;
    return (bytes / (1024 * 1024)).ceil();
  }

  Future<MapOfflineDownloadResult> downloadTiles({
    required TileBounds bounds,
    required List<int> zooms,
    void Function(double progress, int downloaded, int total)? onProgress,
  }) async {
    final baseDir = await _baseTileDirectory();
    await baseDir.create(recursive: true);

    var downloaded = 0;
    var alreadyCached = 0;
    var failed = 0;

    final totalTiles = estimateTileCount(zooms: zooms, bounds: bounds);
    var processedTiles = 0;

    for (final z in zooms) {
      final xMin = _lonToTileX(bounds.minLng, z);
      final xMax = _lonToTileX(bounds.maxLng, z);
      final yMin = _latToTileY(bounds.maxLat, z);
      final yMax = _latToTileY(bounds.minLat, z);

      for (var x = xMin; x <= xMax; x++) {
        for (var y = yMin; y <= yMax; y++) {
          final file = File(p.join(baseDir.path, '$z', '$x', '$y.png'));
          if (await file.exists()) {
            alreadyCached++;
            processedTiles++;
            if (onProgress != null && totalTiles > 0) {
              onProgress(
                processedTiles / totalTiles,
                downloaded + alreadyCached,
                totalTiles,
              );
            }
            continue;
          }

          try {
            await file.parent.create(recursive: true);
            final response = await _httpClient.get(
              Uri.parse(tileUrl(z: z, x: x, y: y)),
            );

            if (response.statusCode >= 200 && response.statusCode < 300) {
              await file.writeAsBytes(response.bodyBytes, flush: true);
              downloaded++;
            } else {
              failed++;
            }
          } catch (_) {
            failed++;
          }

          processedTiles++;
          if (onProgress != null && totalTiles > 0) {
            onProgress(
              processedTiles / totalTiles,
              downloaded + alreadyCached,
              totalTiles,
            );
          }
        }
      }
    }

    return MapOfflineDownloadResult(
      downloaded: downloaded,
      alreadyCached: alreadyCached,
      failed: failed,
    );
  }

  /// Backwards-compatible wrapper used by the legacy callers.
  Future<MapOfflineDownloadResult> downloadTabarkaTiles({
    List<int> zooms = const [11, 12, 13, 14, 15],
    void Function(double progress, int downloaded, int total)? onProgress,
  }) {
    return downloadTiles(
      bounds: TileBounds.tabarka,
      zooms: zooms,
      onProgress: onProgress,
    );
  }

  Future<bool> hasAnyOfflineTile() async {
    final baseDir = await _baseTileDirectory();
    if (!await baseDir.exists()) return false;

    await for (final entity in baseDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.path.endsWith('.png')) {
        return true;
      }
    }
    return false;
  }

  /// Returns the on-disk size of the cached tiles in megabytes.
  Future<double> getCachedTilesSizeMb() async {
    final baseDir = await _baseTileDirectory();
    if (!await baseDir.exists()) return 0;

    var bytes = 0;
    await for (final entity in baseDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        try {
          bytes += await entity.length();
        } catch (_) {}
      }
    }
    return bytes / (1024 * 1024);
  }

  Future<void> clearTabarkaTiles() async {
    final baseDir = await _baseTileDirectory();
    if (await baseDir.exists()) {
      await baseDir.delete(recursive: true);
    }
  }

  static int _lonToTileX(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  static int _latToTileY(double lat, int zoom) {
    final rad = lat * (3.141592653589793 / 180.0);
    final n = (1 << zoom).toDouble();
    return ((1.0 -
                math.log(math.tan(rad) + 1.0 / math.cos(rad)) /
                    3.141592653589793) /
            2.0 *
            n)
        .floor();
  }
}

class LocalFirstTileProvider extends TileProvider {
  final MapOfflineService _mapOfflineService;

  LocalFirstTileProvider({MapOfflineService? service})
    : _mapOfflineService = service ?? MapOfflineService();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final z = coordinates.z.round();
    final x = coordinates.x.round();
    final y = coordinates.y.round();

    if (options.urlTemplate == MapOfflineService.standardTileUrlTemplate) {
      final cachedFile = _mapOfflineService.tileFileSync(z: z, x: x, y: y);
      if (cachedFile != null) {
        return FileImage(cachedFile);
      }
    }

    return NetworkImage(getTileUrl(coordinates, options));
  }
}
