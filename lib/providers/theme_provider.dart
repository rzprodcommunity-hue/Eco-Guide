import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(AppConstants.themeKey);
    if (stored == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (stored == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.dark:
        await prefs.setString(AppConstants.themeKey, 'dark');
      case ThemeMode.light:
        await prefs.setString(AppConstants.themeKey, 'light');
      case ThemeMode.system:
        await prefs.setString(AppConstants.themeKey, 'system');
    }
  }

  Future<void> toggleTheme() async {
    await setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }
}
