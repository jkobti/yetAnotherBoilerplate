import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import 'core/router.dart';

void main() {
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = YabTheme.admin();
    return MaterialApp.router(
      title: 'Admin Portal',
      theme: theme,
      routerConfig: adminRouter(),
    );
  }
}
