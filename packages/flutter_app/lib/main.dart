import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:ui_kit/ui_kit.dart';

import 'core/router.dart';
import 'core/theme/theme_controller.dart';
import 'core/feature_flags/feature_flags_provider.dart';

void main() {
  // Enable path-based URL strategy so deep links like /magic-verify/<token>
  // are properly parsed without requiring a hash (#/). This fixes magic link
  // auto verification when clicking email links in web builds.
  usePathUrlStrategy();
  runApp(const ProviderScope(child: CustomerApp()));
}

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = YabTheme.customer();
    final darkTheme = YabTheme.customerDark();
    final mode = ref.watch(themeModeProvider);
    // Kick off feature flags fetch early (result consumed by home page widgets)
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
