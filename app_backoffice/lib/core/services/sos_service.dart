import '../constants/api_constants.dart';
import '../models/sos_alert_model.dart';
import 'api_service.dart';

class SosService {
  static Future<List<SosAlertModel>> getActiveAlerts() async {
    final response = await ApiService.get(ApiConstants.sosAlertsActive);
    final data = response as List;
    return data.map((json) => SosAlertModel.fromJson(json)).toList();
  }

  static Future<List<SosAlertModel>> getAllAlerts() async {
    final response = await ApiService.get(ApiConstants.sosAlerts);
    final data = response as List;
    return data.map((json) => SosAlertModel.fromJson(json)).toList();
  }

  static Future<void> resolveAlert(String id) async {
    await ApiService.patch('${ApiConstants.sosAlerts}/$id/resolve');
  }
}
