import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../apps/admin_app.dart';
import '../core/theme/theme_controller.dart';
import 'url_strategy_stub.dart' if (dart.library.html) 'url_strategy_web.dart';

/// Starts the admin portal application with shared Riverpod scope.
void runAdminApp({bool enablePathUrlStrategy = true}) {
  if (enablePathUrlStrategy) {
    applyPathUrlStrategy();
  }
  runApp(
    const ProviderScope(
      child: _InitializeTheme(
        child: AdminApp(),
      ),
    ),
  );
}

/// Initializes theme preferences before rendering the app
class _InitializeTheme extends ConsumerStatefulWidget {
  final Widget child;

  const _InitializeTheme({required this.child});

  @override
  ConsumerState<_InitializeTheme> createState() => _InitializeThemeState();
}

class _InitializeThemeState extends ConsumerState<_InitializeTheme> {
  @override
  void initState() {
    super.initState();
    // Initialize theme on first build
    Future.microtask(() {
      ref.read(themeModeProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
