import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_service.dart';
import '../models/poi.dart';
import '../models/trail.dart';
import 'map_offline_service.dart';
import 'offline_cache_service.dart';

/// Seeds the on-device offline cache from assets shipped INSIDE the app, so a
/// fresh install works fully offline — no connection ever required.
///
/// Populate these (optional) assets before building:
///   • assets/offline/tiles.zip   → zip of the `{z}/{x}/{y}.png` tile tree
///   • assets/seed/trails.json    → JSON array of trails  (API shape)
///   • assets/seed/pois.json      → JSON array of POIs
///   • assets/seed/services.json  → JSON array of local services
///
/// Runs once (guarded by a SharedPreferences flag). Any missing asset is simply
/// skipped, so the app builds and runs even before the packs are added.
class OfflineSeedService {
  static const String _seededKey = 'offline_assets_seeded_v1';
  // One-shot migration flag: older installs used to download tiles from
  // tile.openstreetmap.org, which now returns the "403 Access blocked" abuse
  // image. Those stale tiles are still served from the local cache, so we
  // wipe them once per device on next launch. Bumping this constant forces a
  // new wipe.
  static const String _tileMigrationKey = 'offline_tile_cache_migrated_v2';

  static Future<void> seedIfNeeded({MapOfflineService? mapService}) async {
    final prefs = await SharedPreferences.getInstance();
    final service = mapService ?? MapOfflineService();

    // Migrate stale OSM tiles on existing installs (runs at most once).
    if (prefs.getBool(_tileMigrationKey) != true) {
      try {
        await service.clearTabarkaTiles();
        debugPrint('[Seed] Cleared stale tile cache (OSM → Google migration).');
      } catch (e) {
        debugPrint('[Seed] Tile cache wipe failed ($e).');
      }
      await prefs.setBool(_tileMigrationKey, true);
    }

    if (prefs.getBool(_seededKey) == true) return;

    await _seedTiles(service);
    await _seedData();

    await prefs.setBool(_seededKey, true);
  }

  // ── Tiles ────────────────────────────────────────────────────────────────

  static Future<void> _seedTiles(MapOfflineService mapService) async {
    try {
      final data = await rootBundle.load('assets/offline/tiles.zip');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final baseDir = await mapService.baseTileDirectory();
      await baseDir.create(recursive: true);

      var extracted = 0;
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final rel = entry.name.replaceAll('\\', '/');
        if (!rel.toLowerCase().endsWith('.png')) continue;
        final out = File(p.join(baseDir.path, rel));
        await out.parent.create(recursive: true);
        await out.writeAsBytes(entry.content as List<int>);
        extracted++;
      }
      debugPrint('[Seed] Extracted $extracted bundled offline tiles.');
    } catch (e) {
      // No bundled tiles → skip silently.
      debugPrint('[Seed] No bundled tiles to seed ($e).');
    }
  }

  // ── Data (trails / POIs / services) ───────────────────────────────────────

  static Future<void> _seedData() async {
    await _seedTrails();
    await _seedPois();
    await _seedServices();
  }

  static List<dynamic> _decodeArray(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      for (final key in const ['data', 'trails', 'pois', 'services', 'items']) {
        final value = decoded[key];
        if (value is List) return value;
      }
    }
    return const [];
  }

  static Future<void> _seedTrails() async {
    try {
      final raw = await rootBundle.loadString('assets/seed/trails.json');
      final items = _decodeArray(raw)
          .whereType<Map<String, dynamic>>()
          .map(Trail.fromJson)
          .toList();
      if (items.isNotEmpty) {
        await OfflineCacheService.instance.saveTrails(items);
        debugPrint('[Seed] Seeded ${items.length} trails.');
      }
    } catch (e) {
      debugPrint('[Seed] No bundled trails ($e).');
    }
  }

  static Future<void> _seedPois() async {
    try {
      final raw = await rootBundle.loadString('assets/seed/pois.json');
      final items = _decodeArray(raw)
          .whereType<Map<String, dynamic>>()
          .map(Poi.fromJson)
          .toList();
      if (items.isNotEmpty) {
        await OfflineCacheService.instance.savePois(items);
        debugPrint('[Seed] Seeded ${items.length} POIs.');
      }
    } catch (e) {
      debugPrint('[Seed] No bundled POIs ($e).');
    }
  }

  static Future<void> _seedServices() async {
    try {
      final raw = await rootBundle.loadString('assets/seed/services.json');
      final items = _decodeArray(raw)
          .whereType<Map<String, dynamic>>()
          .map(LocalService.fromJson)
          .toList();
      if (items.isNotEmpty) {
        await OfflineCacheService.instance.saveLocalServices(items);
        debugPrint('[Seed] Seeded ${items.length} local services.');
      }
    } catch (e) {
      debugPrint('[Seed] No bundled services ($e).');
    }
  }
}
