import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  return ThemeController();
});

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  void toggle() {
    final newState = switch (state) {
      ThemeMode.system => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
    };
    state = newState;
  }
}
