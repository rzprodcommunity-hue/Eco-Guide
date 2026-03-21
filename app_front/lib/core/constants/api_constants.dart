class ApiConstants {
  // Override at runtime with --dart-define, for example:
  // --dart-define=API_HOST=10.0.2.2 --dart-define=API_PORT=3000
  static const String _host =
      String.fromEnvironment('API_HOST', defaultValue: 'localhost');
  static const String _port =
      String.fromEnvironment('API_PORT', defaultValue: '3000');

  static const String baseUrl = 'http://$_host:$_port/api';

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/auth/profile';

  // Trails endpoints
  static const String trails = '/trails';
  static const String trailsNearby = '/trails/nearby';

  // POIs endpoints
  static const String pois = '/pois';
  static const String poisNearby = '/pois/nearby';

  // Quizzes endpoints
  static const String quizzes = '/quizzes';
  static const String quizzesRandom = '/quizzes/random';

  // Local services endpoints
  static const String localServices = '/local-services';
  static const String localServicesNearby = '/local-services/nearby';

  // Activities endpoints
  static const String activities = '/activities';
  static const String activitiesMe = '/activities/me';
  static const String activitiesStats = '/activities/me/stats';

  // SOS endpoints
  static const String sosAlert = '/sos/alert';

  // Media endpoints
  static const String mediaUpload = '/media/upload/image';
}
