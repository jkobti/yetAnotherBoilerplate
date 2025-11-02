import '../api_client.dart';
import 'token_storage.dart';

class AuthRepository {
  AuthRepository(this._client, this._storage);

  final ApiClient _client;
  final TokenStorage _storage;

  Future<void> init() async {
    await _client.initFromStorage();
  }

  Future<void> login({required String email, required String password}) async {
    final data = await _client.login(email: email, password: password);
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;
    if (access == null) {
      throw Exception('Invalid login response');
    }
    await _storage.saveTokens(access: access, refresh: refresh);
    _client.setAuthToken(access);
  }

  Future<Map<String, dynamic>?> me() async {
    try {
      final data = await _client.me();
      return (data['data'] as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.clear();
    _client.setAuthToken(null);
  }

  Future<void> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final data = await _client.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;
    if (access == null) {
      throw Exception('Invalid register response');
    }
    await _storage.saveTokens(access: access, refresh: refresh);
    _client.setAuthToken(access);
  }
}
