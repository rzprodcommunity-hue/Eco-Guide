import '../constants/api_constants.dart';
import '../models/dashboard_model.dart';
import 'api_service.dart';

class AdminService {
  static Future<DashboardData> getDashboard() async {
    final response = await ApiService.get(ApiConstants.adminDashboard);
    return DashboardData.fromJson(response);
  }
}
