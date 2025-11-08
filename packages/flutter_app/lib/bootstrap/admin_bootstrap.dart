import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../apps/admin_app.dart';
import 'url_strategy_stub.dart' if (dart.library.html) 'url_strategy_web.dart';

/// Starts the admin portal application with shared Riverpod scope.
void runAdminApp({bool enablePathUrlStrategy = true}) {
  if (enablePathUrlStrategy) {
    applyPathUrlStrategy();
  }
  runApp(const ProviderScope(child: AdminApp()));
}
