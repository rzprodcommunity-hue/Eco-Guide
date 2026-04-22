class ApiConstants {
  static const String baseUrl = 'http://localhost:3000/api';

  // Auth endpoints
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String profile = '$baseUrl/auth/profile';

  // Trails endpoints
  static const String trails = '$baseUrl/trails';

  // POIs endpoints
  static const String pois = '$baseUrl/pois';

  // Users endpoints
  static const String users = '$baseUrl/users';

  // Quizzes endpoints
  static const String quizzes = '$baseUrl/quizzes';

  // Local Services endpoints
  static const String localServices = '$baseUrl/local-services';

  // SOS endpoints
  static const String sosAlerts = '$baseUrl/sos/alerts';
  static const String sosAlertsActive = '$baseUrl/sos/alerts/active';

  // Media endpoints
  static const String mediaUploadImage = '$baseUrl/media/upload/image';
  static const String mediaUploadVideo = '$baseUrl/media/upload/video';
  static const String mediaUploadAudio = '$baseUrl/media/upload/audio';

  // Admin endpoints
  static const String adminDashboard = '$baseUrl/admin/dashboard';
}
