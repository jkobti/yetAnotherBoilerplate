import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import 'core/router.dart';

void main() {
  runApp(const ProviderScope(child: CustomerApp()));
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = YabTheme.customer();
    return MaterialApp.router(
      title: 'Customer App',
      theme: theme,
      routerConfig: customerRouter(),
    );
  }
}
