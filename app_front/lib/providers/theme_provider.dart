import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme modes available to the user.
enum AppThemeMode { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'settings_theme_mode';

  AppThemeMode _mode = AppThemeMode.system;

  ThemeProvider() {
    _loadTheme();
  }

  AppThemeMode get mode => _mode;

  /// True when the *effective* theme is dark (used by widgets that need
  /// to know the current resolved state, taking system mode into account).
  bool get isDarkMode {
    if (_mode == AppThemeMode.dark) return true;
    if (_mode == AppThemeMode.light) return false;
    // System: read the platform's current brightness.
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  /// Flutter's `themeMode` (system / light / dark).
  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeKey);
    _mode = AppThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => AppThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
    notifyListeners();
  }

  /// Kept for backwards compatibility with the existing switch tile.
  Future<void> toggleTheme(bool isDark) async {
    await setMode(isDark ? AppThemeMode.dark : AppThemeMode.light);
  }
}
