class AppConstants {
  static const String appName = 'Eco-Guide';
  static const String appVersion = '1.0.0';

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String languageKey = 'language';
  static const String themeKey = 'theme_mode';

  // Default values
  static const int defaultPageSize = 10;
  static const double defaultSearchRadius = 50.0; // km

  // Map settings
  static const double defaultLatitude = 36.9544; // Tabarka Coast
  static const double defaultLongitude = 8.7580;    // Tabarka, Tunisia
  static const double defaultZoom = 12.0;

  // Difficulties
  static const List<String> difficulties = ['easy', 'moderate', 'difficult'];

  // POI types
  static const List<String> poiTypes = [
    'viewpoint',
    'flora',
    'fauna',
    'historical',
    'water',
    'camping',
    'danger',
    'rest_area',
    'information',
  ];

  // Service categories
  static const List<String> serviceCategories = [
    'guide',
    'artisan',
    'accommodation',
    'restaurant',
    'transport',
    'equipment',
  ];
}
