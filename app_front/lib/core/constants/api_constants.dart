import 'package:flutter/foundation.dart';

class ApiConstants {
  // Optional runtime overrides:
  // flutter run --dart-define=API_HOST=192.168.1.100 --dart-define=API_PORT=3000
  static const String _configuredHost = String.fromEnvironment('API_HOST');
  static const String _configuredPort = String.fromEnvironment('API_PORT');

  static String get _host {
    if (_configuredHost.isNotEmpty) {
      return _configuredHost;
    }

    // Android emulator cannot access localhost of the host machine directly.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }

    return 'localhost';
  }

  static String get _port => _configuredPort.isNotEmpty ? _configuredPort : '3000';

  static String get baseUrl => 'http://$_host:$_port/api';

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
