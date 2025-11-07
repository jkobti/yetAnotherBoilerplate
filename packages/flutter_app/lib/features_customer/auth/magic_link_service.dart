import 'package:dio/dio.dart';

class MagicLinkService {
  MagicLinkService(this._dio, {required this.baseUrl});

  final Dio _dio;
  final String baseUrl; // e.g. from env API_BASE_URL

  /// Request a magic link be sent to [email].
  /// Returns true if request accepted.
  Future<bool> requestMagicLink(String email) async {
    final url = Uri.parse('$baseUrl/api/auth/magic/request/');
    final resp = await _dio.post(url.toString(), data: {'email': email});
    // Debug logging
    // ignore: avoid_print
    print(
        '[MagicLinkService] requestMagicLink -> status=${resp.statusCode} baseUrl=$baseUrl');
    return resp.statusCode == 202;
  }

  /// Verify a magic link token obtained from the email redirect.
  /// Returns a map with access, refresh, and user if successful.
  Future<Map<String, dynamic>> verifyMagicLink(String token) async {
    final url = Uri.parse('$baseUrl/api/auth/magic/verify/');
    // ignore: avoid_print
    print('[MagicLinkService] verifyMagicLink POST $url token=$token');
    final resp = await _dio.post(url.toString(), data: {'token': token});
    // ignore: avoid_print
    print(
        '[MagicLinkService] verifyMagicLink <- status=${resp.statusCode} data=${resp.data}');
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(resp.data);
    }
    throw MagicLinkException('Verification failed',
        statusCode: resp.statusCode ?? 0, data: resp.data);
  }
}

class MagicLinkException implements Exception {
  MagicLinkException(this.message, {this.statusCode = 0, this.data});
  final String message;
  final int statusCode;
  final dynamic data;
  @override
  String toString() => 'MagicLinkException($statusCode): $message';
}
