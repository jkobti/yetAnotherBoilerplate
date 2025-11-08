import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/apps/customer_app.dart';
import 'package:flutter_app/core/auth/auth_state.dart';
import 'package:flutter_app/core/feature_flags/feature_flags_provider.dart';

class _InMemoryFeatureFlagsNotifier extends FeatureFlagsNotifier {
  @override
  FutureOr<Set<String>> build() => <String>{};
}

void main() {
  testWidgets('CustomerApp boots with expected title', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagsProvider.overrideWith(_InMemoryFeatureFlagsNotifier.new),
          authStateProvider.overrideWith(
            (ref) => AuthStateController(
              autoInitialize: false,
              initialState: const AsyncValue.data(null),
            ),
          ),
        ],
        child: const CustomerApp(),
      ),
    );
    await tester.pump();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, 'Customer App');
  });
}
