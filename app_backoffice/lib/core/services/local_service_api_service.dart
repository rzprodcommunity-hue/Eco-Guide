import '../constants/api_constants.dart';
import '../models/local_service_model.dart';
import 'api_service.dart';

class LocalServiceApiService {
  static Future<Map<String, dynamic>> getServices({
    int page = 1,
    int limit = 10,
    String? category,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      'includeInactive': 'true',
    };
    if (category != null) queryParams['category'] = category;

    final response = await ApiService.get(
      ApiConstants.localServices,
      queryParams: queryParams,
    );

    final data = response['data'] as List;
    return {
      'services': data.map((json) => LocalServiceModel.fromJson(json)).toList(),
      'meta': response['meta'],
    };
  }

  static Future<LocalServiceModel> getService(String id) async {
    final response = await ApiService.get('${ApiConstants.localServices}/$id');
    return LocalServiceModel.fromJson(response);
  }

  static Future<LocalServiceModel> createService(Map<String, dynamic> data) async {
    final response = await ApiService.post(ApiConstants.localServices, body: data);
    return LocalServiceModel.fromJson(response);
  }

  static Future<LocalServiceModel> updateService(String id, Map<String, dynamic> data) async {
    final response = await ApiService.patch('${ApiConstants.localServices}/$id', body: data);
    return LocalServiceModel.fromJson(response);
  }

  static Future<void> deleteService(String id) async {
    await ApiService.delete('${ApiConstants.localServices}/$id');
  }
}
