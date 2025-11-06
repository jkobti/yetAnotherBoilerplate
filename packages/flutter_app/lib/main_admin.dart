import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import 'core/router.dart';
import 'core/theme/theme_controller.dart';

void main() {
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = YabTheme.admin();
    final darkTheme = YabTheme.adminDark();
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Admin Portal',
      theme: theme,
      darkTheme: darkTheme,
      themeMode: mode,
      routerConfig: adminRouter(),
    );
  }
}
