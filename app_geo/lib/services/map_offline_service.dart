import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Browser-like User-Agent. The tile endpoint returns 403 to the default Dart
/// HTTP user-agent, so both display and downloads send this instead.
const Map<String, String> _tileHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
};

/// A simple lat/lng bounding box used when pre-downloading offline tiles.
class TileBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  final String label;

  const TileBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    this.label = '',
  });

  /// Tabarka coast (Tunisia) — same box as the main Eco-Guide app.
  static const TileBounds tabarka = TileBounds(
    minLat: 36.9000,
    maxLat: 37.0500,
    minLng: 8.7000,
    maxLng: 8.8500,
    label: 'Tabarka',
  );

  /// Jbel Chitana massif (Mogods, Nefza) — same box as the main app.
  static const TileBounds jbelChitana = TileBounds(
    minLat: 37.0000,
    maxLat: 37.1500,
    minLng: 8.9500,
    maxLng: 9.1500,
    label: 'Jbel Chitana',
  );

  /// Build a bounding box around a single (lat, lng) point.
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

/// Tile zoom presets matching a precision selector (like the main app).
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
    label: 'Max',
    zooms: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    maxZoom: 19,
  );

  static const List<OfflineTileMode> values = [eco, standard, detailed, max];
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

/// On-device tile cache + downloader for app_geo, mirroring the offline map in
/// the main Eco-Guide app (same Google "m" layer, same regions).
class MapOfflineService {
  MapOfflineService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Same tile source as the main app (public OSM 403s on bulk fetching).
  static const String tileUrlTemplate =
      'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';

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
    return Directory(p.join(docs.path, 'offline_tiles', 'osm'));
  }

  Future<Directory> baseTileDirectory() => _baseTileDirectory();

  File? tileFileSync({required int z, required int x, required int y}) {
    final base = _baseTilePath ?? _sharedBaseTilePath;
    if (base == null) return null;
    final candidate = File(p.join(base, '$z', '$x', '$y.png'));
    if (candidate.existsSync()) return candidate;
    return null;
  }

  String tileUrl({required int z, required int x, required int y}) {
    return tileUrlTemplate
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
  }

  int estimateTileCount({
    required List<int> zooms,
    required TileBounds bounds,
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

  /// Rough estimate, ~25 KB / tile.
  int estimateSizeMb({required List<int> zooms, required TileBounds bounds}) {
    final tiles = estimateTileCount(zooms: zooms, bounds: bounds);
    final bytes = tiles * 25 * 1024;
    return (bytes / (1024 * 1024)).ceil();
  }

  /// Downloads every tile inside [bounds] for [zooms], skipping cached tiles.
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

    void report() {
      if (onProgress != null && totalTiles > 0) {
        onProgress(
          processedTiles / totalTiles,
          downloaded + alreadyCached,
          totalTiles,
        );
      }
    }

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
            report();
            continue;
          }

          try {
            await file.parent.create(recursive: true);
            final response = await _httpClient.get(
              Uri.parse(tileUrl(z: z, x: x, y: y)),
              headers: _tileHeaders,
            );
            if (response.statusCode >= 200 &&
                response.statusCode < 300 &&
                response.bodyBytes.isNotEmpty) {
              await file.writeAsBytes(response.bodyBytes, flush: true);
              downloaded++;
            } else {
              failed++;
            }
          } catch (_) {
            failed++;
          }

          processedTiles++;
          report();
        }
      }
    }

    return MapOfflineDownloadResult(
      downloaded: downloaded,
      alreadyCached: alreadyCached,
      failed: failed,
    );
  }

  Future<bool> hasAnyOfflineTile() async {
    final baseDir = await _baseTileDirectory();
    if (!await baseDir.exists()) return false;
    await for (final entity in baseDir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.png')) return true;
    }
    return false;
  }

  Future<double> getCachedTilesSizeMb() async {
    final baseDir = await _baseTileDirectory();
    if (!await baseDir.exists()) return 0;
    var bytes = 0;
    await for (final entity in baseDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          bytes += await entity.length();
        } catch (_) {}
      }
    }
    return bytes / (1024 * 1024);
  }

  Future<void> clearTiles() async {
    final baseDir = await _baseTileDirectory();
    if (await baseDir.exists()) await baseDir.delete(recursive: true);
  }

  static int _lonToTileX(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  static int _latToTileY(double lat, int zoom) {
    final rad = lat * (math.pi / 180.0);
    final n = (1 << zoom).toDouble();
    return ((1.0 -
                math.log(math.tan(rad) + 1.0 / math.cos(rad)) / math.pi) /
            2.0 *
            n)
        .floor();
  }
}

/// Serves tiles from the on-disk cache first; falls back to the network for
/// anything not yet downloaded. Mirrors the main app's provider, so display
/// never uses a raw Dart HTTP request (which would 403) — it uses a
/// [NetworkImage] with a browser User-Agent instead.
class LocalFirstTileProvider extends TileProvider {
  final MapOfflineService _service;

  LocalFirstTileProvider({MapOfflineService? service})
    : _service = service ?? MapOfflineService();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final z = coordinates.z.round();
    final x = coordinates.x.round();
    final y = coordinates.y.round();

    final cachedFile = _service.tileFileSync(z: z, x: x, y: y);
    if (cachedFile != null) {
      return FileImage(cachedFile);
    }
    return NetworkImage(
      _service.tileUrl(z: z, x: x, y: y),
      headers: _tileHeaders,
    );
  }
}
