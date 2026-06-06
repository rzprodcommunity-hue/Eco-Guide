import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  static Future<String> uploadBytes({
    required String bucket,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final client = Supabase.instance.client;

    await client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
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
