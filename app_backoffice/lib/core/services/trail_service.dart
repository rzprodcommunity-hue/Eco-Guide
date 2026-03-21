import '../constants/api_constants.dart';
import '../models/trail_model.dart';
import 'api_service.dart';

class TrailService {
  static Future<Map<String, dynamic>> getTrails({
    int page = 1,
    int limit = 10,
    String? difficulty,
    String? region,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      'includeInactive': 'true',
    };
    if (difficulty != null) queryParams['difficulty'] = difficulty;
    if (region != null) queryParams['region'] = region;

    final response = await ApiService.get(
      ApiConstants.trails,
      queryParams: queryParams,
    );

    final data = response['data'] as List;
    return {
      'trails': data.map((json) => TrailModel.fromJson(json)).toList(),
      'meta': response['meta'],
    };
  }

  static Future<TrailModel> getTrail(String id) async {
    final response = await ApiService.get('${ApiConstants.trails}/$id');
    return TrailModel.fromJson(response);
  }

  static Future<TrailModel> createTrail(Map<String, dynamic> data) async {
    final response = await ApiService.post(ApiConstants.trails, body: data);
    return TrailModel.fromJson(response);
  }

  static Future<TrailModel> updateTrail(String id, Map<String, dynamic> data) async {
    final response = await ApiService.patch('${ApiConstants.trails}/$id', body: data);
    return TrailModel.fromJson(response);
  }

  static Future<void> deleteTrail(String id) async {
    await ApiService.delete('${ApiConstants.trails}/$id');
  }
}
