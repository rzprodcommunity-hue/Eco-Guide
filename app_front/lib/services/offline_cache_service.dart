import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/local_service.dart';
import '../models/poi.dart';
import '../models/trail.dart';

class OfflineCacheService {
  OfflineCacheService._();

  static final OfflineCacheService instance = OfflineCacheService._();

  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      p.join(dbPath, 'ecoguide_offline.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_trails (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            downloadedAt TEXT NOT NULL,
            quality TEXT NOT NULL,
            sizeMb REAL NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE offline_pois (
            id TEXT PRIMARY KEY,
            trailId TEXT,
            payload TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE offline_local_services (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            downloadedAt TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS offline_local_services (
              id TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              downloadedAt TEXT NOT NULL
            )
          ''');
        }
      },
    );

    return _database!;
  }

  Future<void> saveTrailPackage({
    required Trail trail,
    required List<Poi> pois,
    required String quality,
    required double sizeMb,
  }) async {
    final db = await _db;

    await db.insert('offline_trails', {
      'id': trail.id,
      'payload': jsonEncode(trail.toJson()),
      'downloadedAt': DateTime.now().toIso8601String(),
      'quality': quality,
      'sizeMb': sizeMb,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    final batch = db.batch();
    for (final poi in pois) {
      batch.insert('offline_pois', {
        'id': poi.id,
        'trailId': trail.id,
        'payload': jsonEncode(poi.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Trail>> getOfflineTrails() async {
    final db = await _db;
    final rows = await db.query('offline_trails', orderBy: 'downloadedAt DESC');

    return rows
        .map(
          (row) => Trail.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<Poi>> getOfflinePois({String? trailId}) async {
    final db = await _db;
    final rows = await db.query(
      'offline_pois',
      where: trailId == null ? null : 'trailId = ?',
      whereArgs: trailId == null ? null : [trailId],
    );

    return rows
        .map(
          (row) => Poi.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> savePois(List<Poi> pois, {String? trailId}) async {
    final db = await _db;
    final batch = db.batch();

    for (final poi in pois) {
      batch.insert('offline_pois', {
        'id': poi.id,
        'trailId': trailId ?? poi.trailId,
        'payload': jsonEncode(poi.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<void> saveLocalServices(List<LocalService> services) async {
    final db = await _db;
    final batch = db.batch();

    for (final service in services) {
      batch.insert('offline_local_services', {
        'id': service.id,
        'payload': jsonEncode(service.toJson()),
        'downloadedAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<List<LocalService>> getOfflineLocalServices() async {
    final db = await _db;
    final rows = await db.query(
      'offline_local_services',
      orderBy: 'downloadedAt DESC',
    );

    return rows
        .map(
          (row) => LocalService.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> clearOfflineLocalServices() async {
    final db = await _db;
    await db.delete('offline_local_services');
  }

  Future<double> getTotalUsageMb() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT SUM(sizeMb) as total FROM offline_trails',
    );
    final value = result.first['total'];

    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0;
  }

  Future<void> removeTrailPackage(String trailId) async {
    final db = await _db;
    await db.delete('offline_trails', where: 'id = ?', whereArgs: [trailId]);
    await db.delete('offline_pois', where: 'trailId = ?', whereArgs: [trailId]);
  }
}
