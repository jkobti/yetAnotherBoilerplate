import 'package:dio/dio.dart';
import 'auth/token_storage.dart';

class ApiClient {
  ApiClient._internal()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            // Do NOT set Content-Type globally to avoid CORS preflight on GET.
            headers: {
              'Accept': 'application/json',
            },
          ),
        );

  static final ApiClient _instance = ApiClient._internal();
  final Dio _dio;

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static ApiClient get I => _instance;

  Dio get dio => _dio;

  // Track current token value for potential future refresh workflows.
  String? get accessToken => _dio.options.headers['Authorization']
      ?.toString()
      .replaceFirst('Bearer ', '');

  Future<void> initFromStorage() async {
    final storage = TokenStorage();
    final token = await storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      setAuthToken(token);
    }
  }

  void setAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<Map<String, dynamic>> health() async {
    final resp = await _dio.get('/health/');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(
      {required String email, required String password}) async {
    final resp = await _dio.post('/api/auth/jwt/token/', data: {
      'email': email,
      'password': password,
    });
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> refresh({required String refreshToken}) async {
    final resp = await _dio.post('/api/auth/jwt/refresh/', data: {
      'refresh': refreshToken,
    });
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> me() async {
    final resp = await _dio.get('/api/v1/me');
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final resp = await _dio.post('/api/auth/register/', data: {
      'email': email,
      'password': password,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
    });
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<void> registerPushToken({
    required String token,
    String platform = 'web',
    String? userAgent,
  }) async {
    await _dio.post('/api/push/register/', data: {
      'token': token,
      'platform': platform,
      if (userAgent != null) 'user_agent': userAgent,
    });
  }

  /// Get list of users with optional filters
  Future<List<Map<String, dynamic>>> getUsers({
    String? email,
    bool? isActive,
    bool? isStaff,
  }) async {
    final queryParams = <String, dynamic>{};
    if (email != null && email.isNotEmpty) {
      queryParams['email'] = email;
    }
    if (isActive != null) {
      queryParams['is_active'] = isActive;
    }
    if (isStaff != null) {
      queryParams['is_staff'] = isStaff;
    }

    final resp = await _dio.get(
      '/admin/api/users',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    return (resp.data['users'] as List).cast<Map<String, dynamic>>();
  }

  /// Get a single user by ID
  Future<Map<String, dynamic>> getUser(String userId) async {
    final resp = await _dio.get('/admin/api/users/$userId');
    return (resp.data as Map).cast<String, dynamic>();
  }
}
