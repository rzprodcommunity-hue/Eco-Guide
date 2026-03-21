import '../core/constants/api_constants.dart';
import '../models/poi.dart';
import 'api_client.dart';

class PoiService {
  final ApiClient _client;

  PoiService(this._client);

  Future<List<Poi>> getPois({
    int page = 1,
    int limit = 10,
    String? type,
    String? trailId,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (type != null) 'type': type,
      if (trailId != null) 'trailId': trailId,
    };

    final response = await _client.get(ApiConstants.pois, queryParams: queryParams);
    final data = response['data'] as List? ?? [];
    return data.map((json) => Poi.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Poi>> getNearbyPois({
    required double lat,
    required double lng,
    double radius = 10,
    String? type,
  }) async {
    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radius.toString(),
      if (type != null) 'type': type,
    };

    final response = await _client.get(ApiConstants.poisNearby, queryParams: queryParams);
    final data = response['data'] as List? ?? response as List;
    return data.map((json) => Poi.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Poi>> getPoisByTrail(String trailId) async {
    final response = await _client.get('${ApiConstants.pois}/trail/$trailId');
    final data = response['data'] as List? ?? response as List;
    return data.map((json) => Poi.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Poi> getPoiById(String id) async {
    final response = await _client.get('${ApiConstants.pois}/$id');
    return Poi.fromJson(response);
  }
}
