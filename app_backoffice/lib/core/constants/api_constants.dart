class ApiConstants {
  static const String _base = '/api';

  // Auth
  static const String login = '$_base/auth/login';
  static const String register = '$_base/auth/register';
  static const String profile = '$_base/auth/profile';

  // Resources
  static const String trails = '$_base/trails';
  static const String pois = '$_base/pois';
  static const String users = '$_base/users';
  static const String quizzes = '$_base/quizzes';
  static const String localServices = '$_base/local-services';

  // SOS
  static const String sosAlerts = '$_base/sos/alerts';
  static const String sosAlertsActive = '$_base/sos/alerts/active';

  // Admin
  static const String adminDashboard = '$_base/admin/dashboard';
}
