import 'api_client.dart';
import '../core/constants/api_constants.dart';

class OfflinePackage {
  final String id;
  final String name;
  final int size;

  OfflinePackage({
    required this.id,
    required this.name,
    required this.size,
  });

  factory OfflinePackage.fromJson(Map<String, dynamic> json) {
    return OfflinePackage(
      id: json['id'] as String,
      name: json['name'] as String,
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class OfflineService {
  final ApiClient _client;

  OfflineService(this._client);

  Future<List<OfflinePackage>> getAvailablePackages() async {
    final response = await _client.get(ApiConstants.offlinePackages);
    final trails = response['trails'] as List? ?? [];

    return trails
        .map((item) => OfflinePackage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> markDownloaded({
    required String resourceType,
    required String resourceId,
    required int sizeBytes,
  }) async {
    await _client.post(
      ApiConstants.offlineDownload,
      body: {
        'resourceType': resourceType,
        'resourceId': resourceId,
        'sizeBytes': sizeBytes,
      },
    );
  }

  Future<void> removeDownload(String cacheId) async {
    await _client.delete('${ApiConstants.offlineDownload}/$cacheId');
  }
}
