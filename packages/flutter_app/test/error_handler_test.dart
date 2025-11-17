import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_app/core/utils/error_handler.dart';

void main() {
  group('ErrorHandler.parseError', () {
    test('extracts message from nested errors format', () {
      // Simulating the exact response from your backend
      final mockResponse = Response(
        requestOptions: RequestOptions(path: '/api/auth/jwt/token/'),
        statusCode: 401,
        data: {
          "type": "about:blank",
          "title": "Incorrect authentication credentials.",
          "status": 401,
          "detail": null,
          "errors": {
            "detail": "No active account found with the given credentials"
          }
        },
      );

      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/jwt/token/'),
        response: mockResponse,
        type: DioExceptionType.badResponse,
      );

      final message = ErrorHandler.parseError(dioException);

      expect(message,
          equals('No active account found with the given credentials'));
    });

    test('extracts message from DRF standard format', () {
      final mockResponse = Response(
        requestOptions: RequestOptions(path: '/api/auth/register/'),
        statusCode: 400,
        data: {
          "email": ["Email already registered"]
        },
      );

      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/register/'),
        response: mockResponse,
        type: DioExceptionType.badResponse,
      );

      final message = ErrorHandler.parseError(dioException);

      expect(message, equals('Email already registered'));
    });

    test('extracts message from top-level detail field', () {
      final mockResponse = Response(
        requestOptions: RequestOptions(path: '/api/auth/login/'),
        statusCode: 401,
        data: {"detail": "Invalid credentials"},
      );

      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/login/'),
        response: mockResponse,
        type: DioExceptionType.badResponse,
      );

      final message = ErrorHandler.parseError(dioException);

      expect(message, equals('Invalid credentials'));
    });

    test('handles timeout errors', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/login/'),
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timeout',
      );

      final message = ErrorHandler.parseError(dioException);

      expect(message, contains('Connection timeout'));
    });

    test('handles network unreachable', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/login/'),
        type: DioExceptionType.unknown,
        message: 'Network is unreachable',
      );

      final message = ErrorHandler.parseError(dioException);

      expect(message, contains('No internet connection'));
    });
  });
}
