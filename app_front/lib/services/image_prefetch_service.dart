import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/poi.dart';
import '../models/trail.dart';

/// Persistently caches trail & POI photos (via the same [DefaultCacheManager]
/// that [CachedNetworkImage] reads from) so they display in offline mode.
///
/// Called after data is loaded online. Best-effort and fire-and-forget: it
/// never throws and skips images already cached.
class ImagePrefetchService {
  ImagePrefetchService._();

  static final BaseCacheManager _cache = DefaultCacheManager();

  /// Caches all photo URLs found in [trails].
  static Future<void> prefetchTrails(List<Trail> trails) async {
    final urls = <String>{};
    for (final t in trails) {
      final imgs = t.imageUrls;
      if (imgs != null) urls.addAll(imgs);
    }
    await _cacheAll(urls);
  }

  /// Caches all photo URLs found in [pois] (skips obvious video links).
  static Future<void> prefetchPois(List<Poi> pois) async {
    final urls = <String>{};
    for (final poi in pois) {
      if (poi.mediaUrl != null &&
          poi.mediaUrl!.isNotEmpty &&
          !_isVideo(poi.mediaUrl!)) {
        urls.add(poi.mediaUrl!);
      }
      final extra = poi.additionalMediaUrls;
      if (extra != null) {
        urls.addAll(extra.where((u) => u.isNotEmpty && !_isVideo(u)));
      }
    }
    await _cacheAll(urls);
  }

  static Future<void> _cacheAll(Set<String> urls) async {
    if (urls.isEmpty) return;
    // Limit concurrency to avoid hammering the network.
    const batchSize = 4;
    final list = urls.toList();
    for (var i = 0; i < list.length; i += batchSize) {
      final batch = list.skip(i).take(batchSize).map(_cacheOne);
      await Future.wait(batch);
    }
  }

  static Future<void> _cacheOne(String url) async {
    if (!url.startsWith('http')) return;
    try {
      // Only fetch if not already stored, so repeat calls are cheap.
      final fileInfo = await _cache.getFileFromCache(url);
      if (fileInfo != null) return;
      await _cache.downloadFile(url);
    } catch (e) {
      debugPrint('[ImagePrefetch] skip $url ($e)');
    }
  }

  static bool _isVideo(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m3u8') ||
        lower.contains('youtube.com') ||
        lower.contains('youtu.be');
  }
}
