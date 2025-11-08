import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/feature_flags/feature_flags_provider.dart';
import '../core/router.dart';
import '../core/theme/theme_controller.dart';

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = YabTheme.customer();
    final darkTheme = YabTheme.customerDark();
    final mode = ref.watch(themeModeProvider);
    // Kick off feature flags fetch early so dependent widgets have data.
    ref.watch(featureFlagsProvider);
    return MaterialApp.router(
      title: 'Customer App',
      theme: theme,
      darkTheme: darkTheme,
      themeMode: mode,
      routerConfig: customerRouter(),
    );
  }
}
