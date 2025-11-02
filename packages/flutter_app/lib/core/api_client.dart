import 'package:dio/dio.dart';

class ApiClient {
  ApiClient._internal()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
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

  Future<Map<String, dynamic>> health() async {
    final resp = await _dio.get('/health/');
    return resp.data as Map<String, dynamic>;
  }
}
