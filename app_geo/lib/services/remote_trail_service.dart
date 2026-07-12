import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/supabase_config.dart';
import '../models/track_point.dart';
import '../models/trail.dart';

/// Downloads Eco-Guide trails from Supabase and caches them on-device so they
/// remain available offline. Trails keep their backend UUID as [Trail.id], so a
/// QR generated here unlocks the exact same trail in the main Eco-Guide app.
class RemoteTrailService {
  RemoteTrailService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static const _cacheDirName = 'eco_trails';

  // ── Network ────────────────────────────────────────────────────────────

  /// Fetches active trails from Supabase (PostgREST).
  Future<List<Trail>> fetchFromSupabase() async {
    final uri = Uri.parse(
      '${SupabaseConfig.restUrl}/trails'
      '?select=*&isActive=eq.true&order=createdAt.desc',
    );
    final response = await _client.get(
      uri,
      headers: const {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Supabase ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <Trail>[];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_trailFromRow)
        .whereType<Trail>()
        .toList();
  }

  // ── Cache ──────────────────────────────────────────────────────────────

  Future<Directory> _cacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_cacheDirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> cache(List<Trail> trails) async {
    final dir = await _cacheDir();
    final file = File('${dir.path}/trails.json');
    await file.writeAsString(
      jsonEncode(trails.map((t) => t.toJson()).toList()),
    );
  }

  Future<List<Trail>> loadCached() async {
    try {
      final dir = await _cacheDir();
      final file = File('${dir.path}/trails.json');
      if (!await file.exists()) return const <Trail>[];
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return const <Trail>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(Trail.fromJson)
          .toList();
    } catch (_) {
      return const <Trail>[];
    }
  }

  /// Convenience: fetch from Supabase then persist.
  Future<List<Trail>> refresh() async {
    final trails = await fetchFromSupabase();
    await cache(trails);
    return trails;
  }

  // ── Mapping ──────────────────────────────────────────────────────────────

  Trail? _trailFromRow(Map<String, dynamic> row) {
    final id = row['id'];
    final name = row['name'];
    if (id is! String || name is! String) return null;

    final createdAt = _parseDate(row['createdAt']);
    final points = _pointsFromGeojson(row['geojson'], createdAt);

    // Fall back to the start coordinate when no route geometry is present.
    if (points.isEmpty) {
      final lat = _toDouble(row['startLatitude']);
      final lng = _toDouble(row['startLongitude']);
      if (lat != null && lng != null) {
        points.add(TrackPoint(latitude: lat, longitude: lng, timestamp: createdAt));
      }
    }

    return Trail(
      id: id,
      name: name,
      startedAt: createdAt,
      endedAt: createdAt,
      points: points,
    );
  }

  List<TrackPoint> _pointsFromGeojson(dynamic geojson, DateTime ts) {
    final points = <TrackPoint>[];
    if (geojson == null) return points;

    dynamic geo = geojson;
    if (geo is String) {
      try {
        geo = jsonDecode(geo);
      } catch (_) {
        return points;
      }
    }
    if (geo is! Map) return points;

    // Unwrap Feature / FeatureCollection wrappers down to a coordinates list.
    dynamic coords;
    final type = geo['type'];
    if (type == 'FeatureCollection' && geo['features'] is List) {
      for (final f in (geo['features'] as List)) {
        if (f is Map && f['geometry'] is Map) {
          coords = (f['geometry'] as Map)['coordinates'];
          _collectCoords(coords, ts, points);
        }
      }
      return points;
    } else if (type == 'Feature' && geo['geometry'] is Map) {
      coords = (geo['geometry'] as Map)['coordinates'];
    } else {
      coords = geo['coordinates'];
    }

    _collectCoords(coords, ts, points);
    return points;
  }

  /// Recursively walks a GeoJSON coordinate tree and appends every [lng, lat]
  /// pair found (handles LineString, MultiLineString, Polygon, etc.).
  void _collectCoords(dynamic coords, DateTime ts, List<TrackPoint> out) {
    if (coords is! List || coords.isEmpty) return;

    final first = coords.first;
    if (first is num && coords.length >= 2 && coords[1] is num) {
      // A single [lng, lat] pair.
      out.add(TrackPoint(
        latitude: (coords[1] as num).toDouble(),
        longitude: (coords[0] as num).toDouble(),
        timestamp: ts,
      ));
      return;
    }
    for (final c in coords) {
      _collectCoords(c, ts, out);
    }
  }

  DateTime _parseDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
