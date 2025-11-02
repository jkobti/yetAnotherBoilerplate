import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';

void main() {
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme =
        ThemeData(colorSchemeSeed: const Color(0xFF0E7C66), useMaterial3: true);
    return MaterialApp.router(
      title: 'Admin Portal',
      theme: theme,
      routerConfig: adminRouter(),
    );
  }
}
