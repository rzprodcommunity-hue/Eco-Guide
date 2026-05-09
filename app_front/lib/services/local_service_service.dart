import '../core/constants/api_constants.dart';
import '../models/local_service.dart';
import 'api_client.dart';

class LocalServiceService {
  final ApiClient _client;

  LocalServiceService(this._client);

  Future<List<LocalService>> getServices({
    int page = 1,
    int limit = 10,
    String? category,
    String? search,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (category != null) 'category': category,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    final response = await _client.get(ApiConstants.localServices, queryParams: queryParams);
    final data = response['data'] as List? ?? [];
    return data.map((json) => LocalService.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<LocalService>> getNearbyServices({
    required double lat,
    required double lng,
    double radius = 50,
    String? category,
  }) async {
    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radius.toString(),
      if (category != null) 'category': category,
    };

    final response = await _client.get(ApiConstants.localServicesNearby, queryParams: queryParams);
    final data = response['data'] as List? ?? response as List;
    return data.map((json) => LocalService.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<LocalService> getServiceById(String id) async {
    final response = await _client.get('${ApiConstants.localServices}/$id');
    return LocalService.fromJson(response);
  }
}
