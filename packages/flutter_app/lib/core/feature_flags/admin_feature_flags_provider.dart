import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';

/// Admin-only feature flags provider exposing full flag objects from
/// `/admin/api/features` with create/toggle/delete helpers.
class AdminFeatureFlagsNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  FutureOr<List<Map<String, dynamic>>> build() async => _fetch();

  Future<List<Map<String, dynamic>>> _fetch() async {
    try {
      final resp = await ApiClient.I.dio.get('/admin/api/features');
      return (resp.data['flags'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> createFlag({
    required String key,
    required String name,
    String description = '',
    bool enabled = true,
  }) async {
    await ApiClient.I.dio.post('/admin/api/features', data: {
      'key': key,
      'name': name,
      'description': description,
      'enabled': enabled,
    });
    await refresh();
  }

  Future<void> toggleFlag({required String id, required bool enabled}) async {
    await ApiClient.I.dio.patch('/admin/api/features/$id', data: {
      'enabled': !enabled,
    });
    await refresh();
  }

  Future<void> deleteFlag(String id) async {
    await ApiClient.I.dio.delete('/admin/api/features/$id');
    await refresh();
  }
}

final adminFeatureFlagsProvider = AsyncNotifierProvider<
    AdminFeatureFlagsNotifier, List<Map<String, dynamic>>>(
  AdminFeatureFlagsNotifier.new,
);
