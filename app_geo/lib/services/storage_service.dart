import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/trail.dart';
import 'gpx_service.dart';

class StorageService {
  static const _trailsDirName = 'trails';
  final GpxService _gpx = GpxService();

  Future<Directory> _trailsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_trailsDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> saveTrail(Trail trail) async {
    final dir = await _trailsDir();
    final file = File('${dir.path}/${trail.id}.json');
    await file.writeAsString(jsonEncode(trail.toJson()));
    return file;
  }

  Future<List<Trail>> listTrails() async {
    final dir = await _trailsDir();
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.json'))
        .toList();

    final trails = <Trail>[];
    for (final f in files) {
      try {
        final raw = await File(f.path).readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        trails.add(Trail.fromJson(json));
      } catch (_) {
        // skip corrupted entries
      }
    }
    trails.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return trails;
  }

  Future<void> deleteTrail(Trail trail) async {
    final dir = await _trailsDir();
    final file = File('${dir.path}/${trail.id}.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Writes the trail as a GPX file in the temporary directory and returns
  /// the file (useful for sharing).
  Future<File> exportToGpxTempFile(Trail trail) async {
    final tmp = await getTemporaryDirectory();
    final safeName = trail.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${tmp.path}/$safeName.gpx');
    await file.writeAsString(_gpx.buildGpx(trail));
    return file;
  }
}
