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

class MapOfflineService {
  MapOfflineService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const List<int> _defaultZooms = <int>[11, 12, 13, 14, 15];
  static const String _tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  final http.Client _httpClient;
  String? _baseTilePath;

  Future<void> initialize() async {
    final baseDir = await _baseTileDirectory();
    _baseTilePath = baseDir.path;
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
    final base = _baseTilePath;
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

  int estimateTileCount({List<int> zooms = _defaultZooms}) {
    var total = 0;
    for (final z in zooms) {
      final xMin = _lonToTileX(TabarkaMapBounds.minLng, z);
      final xMax = _lonToTileX(TabarkaMapBounds.maxLng, z);
      final yMin = _latToTileY(TabarkaMapBounds.maxLat, z);
      final yMax = _latToTileY(TabarkaMapBounds.minLat, z);
      total += (xMax - xMin + 1) * (yMax - yMin + 1);
    }
    return total;
  }

  Future<MapOfflineDownloadResult> downloadTabarkaTiles({
    List<int> zooms = _defaultZooms,
    void Function(double progress, int downloaded, int total)? onProgress,
  }) async {
    final baseDir = await _baseTileDirectory();
    await baseDir.create(recursive: true);

    var downloaded = 0;
    var alreadyCached = 0;
    var failed = 0;

    final totalTiles = estimateTileCount(zooms: zooms);
    var processedTiles = 0;

    for (final z in zooms) {
      final xMin = _lonToTileX(TabarkaMapBounds.minLng, z);
      final xMax = _lonToTileX(TabarkaMapBounds.maxLng, z);
      final yMin = _latToTileY(TabarkaMapBounds.maxLat, z);
      final yMax = _latToTileY(TabarkaMapBounds.minLat, z);

      for (var x = xMin; x <= xMax; x++) {
        for (var y = yMin; y <= yMax; y++) {
          final file = File(p.join(baseDir.path, '$z', '$x', '$y.png'));
          if (await file.exists()) {
            alreadyCached++;
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
            onProgress(processedTiles / totalTiles, downloaded + alreadyCached, totalTiles);
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

    final cachedFile = _mapOfflineService.tileFileSync(z: z, x: x, y: y);
    if (cachedFile != null) {
      return FileImage(cachedFile);
    }

    final url = _mapOfflineService.tileUrl(z: z, x: x, y: y);
    return NetworkImage(url);
  }
}
