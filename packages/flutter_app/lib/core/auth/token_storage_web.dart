import 'dart:html' as html;

class TokenStorage {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  Future<void> saveTokens({required String access, String? refresh}) async {
    html.window.localStorage[_kAccess] = access;
    if (refresh != null) {
      html.window.localStorage[_kRefresh] = refresh;
    }
  }

  Future<String?> getAccessToken() async => html.window.localStorage[_kAccess];

  Future<String?> getRefreshToken() async =>
      html.window.localStorage[_kRefresh];

  Future<void> clear() async {
    html.window.localStorage.remove(_kAccess);
    html.window.localStorage.remove(_kRefresh);
  }
}
