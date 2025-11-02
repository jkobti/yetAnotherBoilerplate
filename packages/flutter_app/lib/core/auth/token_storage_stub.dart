class TokenStorage {
  String? _access;
  String? _refresh;

  Future<void> saveTokens({required String access, String? refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  Future<String?> getAccessToken() async => _access;
  Future<String?> getRefreshToken() async => _refresh;

  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}
