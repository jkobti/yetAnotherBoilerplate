import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import '../organizations/organization.dart';
import '../organizations/organization_provider.dart';
import 'auth_repository.dart';
import 'token_storage.dart';

final authStateProvider = StateNotifierProvider<AuthStateController,
    AsyncValue<Map<String, dynamic>?>>((ref) {
  return AuthStateController(ref);
});

class AuthStateController
    extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  AuthStateController(
    this._ref, {
    AuthRepository? repository,
    AsyncValue<Map<String, dynamic>?>? initialState,
    bool autoInitialize = true,
  })  : _repo = repository ?? AuthRepository(ApiClient.I, TokenStorage()),
        super(initialState ?? const AsyncValue.loading()) {
    if (autoInitialize) {
      _initialize();
    }
  }

  final Ref _ref;
  final AuthRepository _repo;

  Future<void> _initialize() async {
    await _repo.init();
    await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final me = await _repo.me();
      state = AsyncValue.data(me);

      // Update current organization from user data
      if (me != null) {
        final orgData = me['current_organization'] as Map<String, dynamic>?;
        _ref
            .read(currentOrganizationProvider.notifier)
            .setFromUserData(orgData);
      } else {
        _ref.read(currentOrganizationProvider.notifier).clear();
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _repo.logout();
    state = const AsyncValue.data(null);

    // Clear organization state
    _ref.read(currentOrganizationProvider.notifier).clear();
    _ref.read(organizationsProvider.notifier).clear();
  }

  /// Get the current organization from auth state.
  Organization? get currentOrganization {
    final userData = state.valueOrNull;
    if (userData == null) return null;
    final orgData = userData['current_organization'] as Map<String, dynamic>?;
    if (orgData == null) return null;
    return Organization.fromJson(orgData);
  }
}
