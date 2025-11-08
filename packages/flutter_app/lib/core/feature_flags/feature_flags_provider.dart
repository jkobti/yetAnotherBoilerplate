import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';

/// Simple in-memory feature flags store fetched from backend `/api/features/`.
/// Returns a set of enabled flag keys; missing key => disabled.
class FeatureFlagsNotifier extends AsyncNotifier<Set<String>> {
  @override
  FutureOr<Set<String>> build() async {
    return _fetch();
  }

  Future<Set<String>> _fetch() async {
    try {
      final resp = await ApiClient.I.dio.get('/api/features/');
      final list = (resp.data['flags'] as List).cast<String>();
      return Set<String>.from(list);
    } catch (e) {
      // Surface empty set on failure; UI can choose to hide gated components.
      return <String>{};
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  bool isEnabled(String key) {
    final current = state.asData?.value;
    if (current == null) return false;
    return current.contains(key);
  }
}

final featureFlagsProvider =
    AsyncNotifierProvider<FeatureFlagsNotifier, Set<String>>(
  FeatureFlagsNotifier.new,
);

/// Convenience selector so widgets only rebuild when a specific flag changes.
final featureFlagSelectorProvider = Provider.family<bool, String>((ref, key) {
  final flagsAsync = ref.watch(featureFlagsProvider);
  return flagsAsync.maybeWhen(
    data: (flags) => flags.contains(key),
    orElse: () => false,
  );
});
