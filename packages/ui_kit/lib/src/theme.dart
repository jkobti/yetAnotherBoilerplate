import 'package:flutter/material.dart';

class YabTheme {
  YabTheme._();

  static ThemeData customer() => _base(seed: const Color(0xFF0066FF));
  static ThemeData admin() => _base(seed: const Color(0xFF0E7C66));

  static const spacing = _Spacing();

  static ThemeData _base({required Color seed}) {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
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
