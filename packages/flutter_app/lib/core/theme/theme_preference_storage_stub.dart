import 'package:flutter/material.dart';

class ThemePreferenceStorage {
  static const _kThemeMode = 'theme_mode';
  ThemeMode _cached = ThemeMode.system;

  /// Save the user's theme preference (in-memory for stub)
  Future<void> saveThemeMode(ThemeMode mode) async {
    _cached = mode;
  }

  /// Load the user's saved theme preference
  /// Returns ThemeMode.system if no preference is saved
  Future<ThemeMode> getThemeMode() async {
    return _cached;
  }

  /// Clear the saved theme preference
  Future<void> clear() async {
    _cached = ThemeMode.system;
  }

  String _themeModeToString(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  ThemeMode _stringToThemeMode(String value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
