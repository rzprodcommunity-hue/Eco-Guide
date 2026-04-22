import '../constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class UserService {
  static Future<Map<String, dynamic>> getUsers({
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final response = await ApiService.get(
      ApiConstants.users,
      queryParams: queryParams,
    );

    final data = response['data'] as List? ?? response as List;
    final users = data.map((json) => UserModel.fromJson(json)).toList();

    return {
      'users': users,
      'meta': response['meta'] ?? {'total': users.length, 'page': page, 'limit': limit},
    };
  }

  static Future<UserModel> getUser(String id) async {
    final response = await ApiService.get('${ApiConstants.users}/$id');
    return UserModel.fromJson(response);
  }

  static Future<UserModel> updateUser(String id, Map<String, dynamic> data) async {
    final response = await ApiService.patch('${ApiConstants.users}/$id', body: data);
    return UserModel.fromJson(response);
  }

  static Future<void> deleteUser(String id) async {
    await ApiService.delete('${ApiConstants.users}/$id');
  }
}
