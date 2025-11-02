import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';

void main() {
  runApp(const ProviderScope(child: CustomerApp()));
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme =
        ThemeData(colorSchemeSeed: const Color(0xFF0066FF), useMaterial3: true);
    return MaterialApp.router(
      title: 'Customer App',
      theme: theme,
      routerConfig: customerRouter(),
    );
  }
}
