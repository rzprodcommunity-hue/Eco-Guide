import '../core/constants/api_constants.dart';
import 'api_client.dart';

class SosService {
  final ApiClient _client;

  SosService(this._client);

  Future<void> sendAlert({
    required double latitude,
    required double longitude,
    String? message,
    String? emergencyContact,
  }) async {
    await _client.post(
      ApiConstants.sosAlert,
      body: {
        'latitude': latitude,
        'longitude': longitude,
        if (message != null) 'message': message,
        if (emergencyContact != null) 'emergencyContact': emergencyContact,
      },
    );
  }
}
