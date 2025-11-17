import 'dart:html' as html;
import 'package:flutter/material.dart';

class ThemePreferenceStorage {
  static const _kThemeMode = 'theme_mode';

  /// Save the user's theme preference to localStorage
  Future<void> saveThemeMode(ThemeMode mode) async {
    html.window.localStorage[_kThemeMode] = _themeModeToString(mode);
  }

  /// Load the user's saved theme preference from localStorage
  /// Returns ThemeMode.system if no preference is saved
  Future<ThemeMode> getThemeMode() async {
    final saved = html.window.localStorage[_kThemeMode];
    if (saved == null) {
      return ThemeMode.system;
    }
    return _stringToThemeMode(saved);
  }

  /// Clear the saved theme preference
  Future<void> clear() async {
    html.window.localStorage.remove(_kThemeMode);
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
