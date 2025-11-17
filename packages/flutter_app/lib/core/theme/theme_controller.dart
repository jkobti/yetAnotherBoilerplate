import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_preference_storage.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  return ThemeController();
});

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);

  final _storage = ThemePreferenceStorage();

  /// Initialize the theme controller by loading saved preference from storage
  /// Should be called during app startup
  Future<void> initialize() async {
    try {
      final saved = await _storage.getThemeMode();
      state = saved;
    } catch (e) {
      // If initialization fails, fall back to system default
      state = ThemeMode.system;
    }
  }

  /// Set theme mode and persist to storage
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      await _storage.saveThemeMode(mode);
    } catch (e) {
      // If save fails, still update the UI state
      // but log the error in production
    }
  }

  /// Toggle theme between light/dark
  /// When on system, switches to dark; from dark to light; from light to dark
  Future<void> toggle() async {
    final newState = switch (state) {
      ThemeMode.system => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
    };
    await setThemeMode(newState);
  }
}
