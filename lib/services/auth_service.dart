import '../core/constants/api_constants.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _client;

  AuthService(this._client);

  Future<AuthResponse> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final response = await _client.post(
      ApiConstants.register,
      body: {
        'email': email,
        'password': password,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
      },
    );
    return AuthResponse.fromJson(response);
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      ApiConstants.login,
      body: {
        'email': email,
        'password': password,
      },
    );
    return AuthResponse.fromJson(response);
  }

  Future<User> getProfile() async {
    final response = await _client.get(ApiConstants.profile);
    return User.fromJson(response);
  }
}

class AuthResponse {
  final String accessToken;
  final User user;

  AuthResponse({
    required this.accessToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final payload = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    final token = payload['access_token'] ?? payload['accessToken'];
    final userJson = payload['user'];

    if (token is! String || userJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid auth response format');
    }

    return AuthResponse(
      accessToken: token,
      user: User.fromJson(userJson),
    );
  }
}
