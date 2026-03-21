import '../constants/api_constants.dart';
import '../models/poi_model.dart';
import 'api_service.dart';

class PoiService {
  static Future<Map<String, dynamic>> getPois({
    int page = 1,
    int limit = 10,
    String? type,
    String? trailId,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      'includeInactive': 'true',
    };
    if (type != null) queryParams['type'] = type;
    if (trailId != null) queryParams['trailId'] = trailId;

    final response = await ApiService.get(
      ApiConstants.pois,
      queryParams: queryParams,
    );

    final data = response['data'] as List;
    return {
      'pois': data.map((json) => PoiModel.fromJson(json)).toList(),
      'meta': response['meta'],
    };
  }

  static Future<PoiModel> getPoi(String id) async {
    final response = await ApiService.get('${ApiConstants.pois}/$id');
    return PoiModel.fromJson(response);
  }

  static Future<PoiModel> createPoi(Map<String, dynamic> data) async {
    final response = await ApiService.post(ApiConstants.pois, body: data);
    return PoiModel.fromJson(response);
  }

  static Future<PoiModel> updatePoi(String id, Map<String, dynamic> data) async {
    final response = await ApiService.patch('${ApiConstants.pois}/$id', body: data);
    return PoiModel.fromJson(response);
  }

  static Future<void> deletePoi(String id) async {
    await ApiService.delete('${ApiConstants.pois}/$id');
  }
}
