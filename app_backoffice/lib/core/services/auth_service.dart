import '../constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await ApiService.post(
      ApiConstants.login,
      body: {
        'email': email,
        'password': password,
      },
    );

    final token = response['accessToken'] as String?;
    if (token != null) {
      await ApiService.saveToken(token);
    }

    return response;
  }

  static Future<void> logout() async {
    await ApiService.clearToken();
  }

  static Future<UserModel> getProfile() async {
    final response = await ApiService.get(ApiConstants.profile);
    return UserModel.fromJson(response);
  }

  static Future<bool> isAuthenticated() async {
    await ApiService.loadToken();
    if (ApiService.token == null) return false;

    try {
      await getProfile();
      return true;
    } catch (e) {
      await ApiService.clearToken();
      return false;
    }
  }
}
