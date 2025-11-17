import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/feature_flags/feature_flags_provider.dart';
import '../core/router.dart';
import '../core/theme/theme_controller.dart';

class CustomerApp extends ConsumerStatefulWidget {
  const CustomerApp({super.key});

  @override
  ConsumerState<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends ConsumerState<CustomerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Force rebuild when app resumes to catch system theme changes
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = YabTheme.customer();
    final darkTheme = YabTheme.customerDark();
    final mode = ref.watch(themeModeProvider);
    // Watch MediaQuery to trigger rebuild on system theme changes
    MediaQuery.of(context);
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
