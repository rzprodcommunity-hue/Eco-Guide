import 'dart:typed_data';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  static Future<String> uploadBytes({
    required String bucket,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    // Keep max strictly > 0 and web-safe (no 1 << 32 overflow on JS).
    final randomSuffix = Random().nextInt(0x7fffffff).toRadixString(16);
    final path = '${DateTime.now().microsecondsSinceEpoch}_${randomSuffix}_$safeName';
    final client = Supabase.instance.client;

    await client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return client.storage.from(bucket).getPublicUrl(path);
  }

  static const int maxVideoBytes = 100 * 1024 * 1024; // 100 MB

  static Future<String> uploadVideo({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!fileName.toLowerCase().endsWith('.mp4')) {
      throw Exception('Format invalide : seul le MP4 est accepté.');
    }
    if (bytes.length > maxVideoBytes) {
      throw Exception('La vidéo dépasse 100 Mo.');
    }

    return uploadBytes(
      bucket: 'images',
      fileName: fileName,
      bytes: bytes,
      contentType: 'video/mp4',
    );
  }
}
