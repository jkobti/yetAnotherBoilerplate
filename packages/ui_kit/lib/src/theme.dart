import 'package:flutter/material.dart';

class YabTheme {
  YabTheme._();

  static ThemeData customer() => _base(seed: const Color(0xFF0066FF));
  static ThemeData admin() => _base(seed: const Color(0xFF0E7C66));
  static ThemeData customerDark() =>
      _base(seed: const Color(0xFF0066FF), brightness: Brightness.dark);
  static ThemeData adminDark() =>
      _base(seed: const Color(0xFF0E7C66), brightness: Brightness.dark);

  static const spacing = _Spacing();

  static ThemeData _base({required Color seed, Brightness brightness = Brightness.light}) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}

class _Spacing {
  const _Spacing();
  double get xs => 4;
  double get sm => 8;
  double get md => 12;
  double get lg => 16;
  double get xl => 24;
}
