import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;

  bool get isInitialized => _isInitialized;

  bool get isUsingSystemTheme {
    return _themeMode == ThemeMode.system;
  }

  bool get isLightMode {
    return _themeMode == ThemeMode.light;
  }

  bool get isDarkMode {
    return _themeMode == ThemeMode.dark;
  }

  String get currentLabel {
    return labelFor(_themeMode);
  }

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();

    final savedMode = preferences.getString(_themeModeKey);

    _themeMode = _themeModeFromString(savedMode);
    _isInitialized = true;

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }

    _themeMode = mode;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_themeModeKey, _themeModeToString(mode));
  }

  Future<void> useSystemTheme() async {
    await setThemeMode(ThemeMode.system);
  }

  Future<void> useLightTheme() async {
    await setThemeMode(ThemeMode.light);
  }

  Future<void> useDarkTheme() async {
    await setThemeMode(ThemeMode.dark);
  }

  String labelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';

      case ThemeMode.light:
        return 'Light';

      case ThemeMode.dark:
        return 'Dark';
    }
  }

  String descriptionFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Match your device appearance automatically.';

      case ThemeMode.light:
        return 'Use a bright appearance throughout the app.';

      case ThemeMode.dark:
        return 'Use a darker appearance for low-light environments.';
    }
  }

  IconData iconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.settings_suggest_outlined;

      case ThemeMode.light:
        return Icons.light_mode_outlined;

      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
    }
  }

  ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;

      case 'dark':
        return ThemeMode.dark;

      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';

      case ThemeMode.light:
        return 'light';

      case ThemeMode.dark:
        return 'dark';
    }
  }
}
