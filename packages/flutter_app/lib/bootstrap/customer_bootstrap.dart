import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../apps/customer_app.dart';
import '../core/theme/theme_controller.dart';
import 'url_strategy_stub.dart' if (dart.library.html) 'url_strategy_web.dart';

/// Starts the customer-facing Flutter application.
///
/// [enablePathUrlStrategy] ensures that web builds use path-based URLs for
/// deep links, while mobile platforms simply no-op.
void runCustomerApp({bool enablePathUrlStrategy = true}) {
  if (enablePathUrlStrategy) {
    applyPathUrlStrategy();
  }
  runApp(
    const ProviderScope(
      child: _InitializeTheme(
        child: CustomerApp(),
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
