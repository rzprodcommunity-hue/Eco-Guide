import '../core/constants/api_constants.dart';
import '../models/activity.dart';
import 'api_client.dart';

class ActivityService {
  final ApiClient _client;

  ActivityService(this._client);

  Future<void> logActivity({
    required String type,
    String? trailId,
    String? poiId,
    Map<String, dynamic>? metadata,
  }) async {
    await _client.post(
      ApiConstants.activities,
      body: {
        'type': type,
        if (trailId != null) 'trailId': trailId,
        if (poiId != null) 'poiId': poiId,
        if (metadata != null) 'metadata': metadata,
      },
    );
  }

  Future<List<Activity>> getMyActivities({int page = 1, int limit = 10}) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final response = await _client.get(ApiConstants.activitiesMe, queryParams: queryParams);
    final data = response['data'] as List? ?? [];
    return data.map((json) => Activity.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<UserStats> getMyStats() async {
    final response = await _client.get(ApiConstants.activitiesStats);
    return UserStats.fromJson(response);
  }

  Future<List<Activity>> getRecentActivities({int limit = 10}) async {
    final queryParams = <String, String>{'limit': limit.toString()};
    final response = await _client.get('${ApiConstants.activitiesMe}/recent', queryParams: queryParams);
    final data = response['data'] as List? ?? response as List;
    return data.map((json) => Activity.fromJson(json as Map<String, dynamic>)).toList();
  }
}
