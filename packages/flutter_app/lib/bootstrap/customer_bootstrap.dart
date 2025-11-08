import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../apps/customer_app.dart';
import 'url_strategy_stub.dart' if (dart.library.html) 'url_strategy_web.dart';

/// Starts the customer-facing Flutter application.
///
/// [enablePathUrlStrategy] ensures that web builds use path-based URLs for
/// deep links, while mobile platforms simply no-op.
void runCustomerApp({bool enablePathUrlStrategy = true}) {
  if (enablePathUrlStrategy) {
    applyPathUrlStrategy();
  }
  runApp(const ProviderScope(child: CustomerApp()));
}
