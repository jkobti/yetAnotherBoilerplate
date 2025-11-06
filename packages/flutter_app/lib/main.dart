import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import 'core/router.dart';
import 'core/theme/theme_controller.dart';

void main() {
  runApp(const ProviderScope(child: CustomerApp()));
}

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = YabTheme.customer();
    final darkTheme = YabTheme.customerDark();
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Customer App',
      theme: theme,
      darkTheme: darkTheme,
      themeMode: mode,
      routerConfig: customerRouter(),
    );
  }
}
