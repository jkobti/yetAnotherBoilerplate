import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import 'auth_repository.dart';
import 'token_storage.dart';

final authStateProvider = StateNotifierProvider<AuthStateController, AsyncValue<Map<String, dynamic>?>>((ref) {
  return AuthStateController();
});

class AuthStateController extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  AuthStateController() : super(const AsyncValue.loading()) {
    _initialize();
  }

  final AuthRepository _repo = AuthRepository(ApiClient.I, TokenStorage());

  Future<void> _initialize() async {
    await _repo.init();
    await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final me = await _repo.me();
      state = AsyncValue.data(me);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _repo.logout();
    state = const AsyncValue.data(null);
  }
}
