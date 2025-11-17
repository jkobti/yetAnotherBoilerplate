import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/router.dart';
import '../core/theme/theme_controller.dart';

class AdminApp extends ConsumerStatefulWidget {
  const AdminApp({super.key});

  @override
  ConsumerState<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends ConsumerState<AdminApp>
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
    final theme = YabTheme.admin();
    final darkTheme = YabTheme.adminDark();
    final mode = ref.watch(themeModeProvider);
    // Watch MediaQuery to trigger rebuild on system theme changes
    MediaQuery.of(context);
    return MaterialApp.router(
      title: 'Admin Portal',
      theme: theme,
      darkTheme: darkTheme,
      themeMode: mode,
      routerConfig: adminRouter(),
    );
  }
}
