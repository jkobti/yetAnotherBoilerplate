import 'package:dio/dio.dart';

/// Handles API errors and converts them to user-friendly messages.
///
/// Best practices:
/// - Differentiates between validation errors (field-specific), auth errors, and server errors
/// - Provides actionable, non-technical messages
/// - Supports structured error responses from the API
/// - Gracefully handles network and unknown errors
class ErrorHandler {
  /// Parse a Dio exception and return a user-friendly error message.
  ///
  /// Returns:
  /// - Validation error: field-specific message from API (e.g., "Email already registered")
  /// - Auth error: descriptive message (e.g., "Invalid credentials")
  /// - Network error: connection message (e.g., "Unable to connect")
  /// - Server error: generic message with status code
  /// - Unknown: generic error message
  static String parseError(dynamic error) {
    if (error is DioException) {
      return _parseDioException(error);
    } else if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  static String _parseDioException(DioException dioError) {
    // Log the full error for debugging
    // ignore: avoid_print
    print(
        '[ErrorHandler] DioException: type=${dioError.type}, statusCode=${dioError.response?.statusCode}');
    // ignore: avoid_print
    print('[ErrorHandler] Response data: ${dioError.response?.data}');
    // ignore: avoid_print
    print('[ErrorHandler] Error message: ${dioError.message}');

    // Network/timeout errors
    if (dioError.type == DioExceptionType.connectionTimeout ||
        dioError.type == DioExceptionType.receiveTimeout ||
        dioError.type == DioExceptionType.sendTimeout) {
      return 'Connection timeout. Please check your internet connection and try again.';
    }

    if (dioError.type == DioExceptionType.unknown) {
      if (dioError.message?.contains('Connection refused') ?? false) {
        return 'Unable to connect to the server. Please check your internet connection.';
      }
      if (dioError.message?.contains('Network is unreachable') ?? false) {
        return 'No internet connection. Please check your network.';
      }
      return 'Network error. Please check your internet connection and try again.';
    }

    // HTTP response errors
    if (dioError.response != null) {
      final statusCode = dioError.response!.statusCode ?? 0;
      final responseData = dioError.response!.data;

      // 400 Bad Request - likely validation errors
      if (statusCode == 400) {
        final extracted = _extractErrorMessage(responseData);
        // ignore: avoid_print
        print('[ErrorHandler] 400 error, extracted: $extracted');
        return extracted ?? 'Please check your input and try again.';
      }

      // 401 Unauthorized - auth failure
      if (statusCode == 401) {
        final extracted = _extractErrorMessage(responseData);
        // ignore: avoid_print
        print('[ErrorHandler] 401 error, extracted: $extracted');
        return extracted ?? 'Invalid email or password. Please try again.';
      }

      // 403 Forbidden
      if (statusCode == 403) {
        return 'You do not have permission to perform this action.';
      }

      // 409 Conflict (e.g., duplicate email)
      if (statusCode == 409) {
        final extracted = _extractErrorMessage(responseData);
        return extracted ??
            'This resource already exists. Please try a different value.';
      }

      // 429 Rate limit
      if (statusCode == 429) {
        return 'Too many attempts. Please wait a moment and try again.';
      }

      // 500+ Server errors
      if (statusCode >= 500) {
        return 'Server error. Please try again later.';
      }

      // Generic HTTP error
      final extracted = _extractErrorMessage(responseData);
      // ignore: avoid_print
      print(
          '[ErrorHandler] Generic HTTP error $statusCode, extracted: $extracted');
      return extracted ??
          'An error occurred (Error $statusCode). Please try again.';
    }

    return 'An unexpected error occurred. Please try again.';
  }

  /// Extract error message from various API response formats.
  ///
  /// Handles:
  /// - DRF standard: {"field": ["error message"]} or {"detail": "message"}
  /// - Nested errors: {"errors": {"detail": "message"}}
  /// - Custom: {"error": "message"} or {"message": "message"}
  /// - List of strings: ["error1", "error2"]
  static String? _extractErrorMessage(dynamic responseData) {
    // ignore: avoid_print
    print(
        '[ErrorHandler] Extracting message from: $responseData (type: ${responseData.runtimeType})');

    if (responseData == null) return null;

    if (responseData is Map) {
      // ignore: avoid_print
      print(
          '[ErrorHandler] Response is a Map with keys: ${responseData.keys.toList()}');

      // Try common error field names at top level
      for (final key in ['detail', 'error', 'message', 'non_field_errors']) {
        final value = responseData[key];
        // ignore: avoid_print
        print('[ErrorHandler] Checking top-level key "$key": $value');
        if (value != null) {
          final formatted = _formatValue(value);
          // ignore: avoid_print
          print('[ErrorHandler] Found at "$key", returning: $formatted');
          return formatted;
        }
      }

      // Try nested errors object (e.g., {"errors": {"detail": "message"}})
      if (responseData.containsKey('errors') && responseData['errors'] is Map) {
        // ignore: avoid_print
        print('[ErrorHandler] Found nested "errors" object');
        final errorsMap = responseData['errors'] as Map;
        for (final key in ['detail', 'error', 'message']) {
          final value = errorsMap[key];
          // ignore: avoid_print
          print('[ErrorHandler] Checking nested key "$key": $value');
          if (value != null) {
            final formatted = _formatValue(value);
            // ignore: avoid_print
            print('[ErrorHandler] Found at errors.$key, returning: $formatted');
            return formatted;
          }
        }
        // Try first error in nested map
        if (errorsMap.isNotEmpty) {
          final firstValue = errorsMap.values.first;
          // ignore: avoid_print
          print('[ErrorHandler] Using first value from errors: $firstValue');
          return _formatValue(firstValue);
        }
      }

      // Try to extract first field error (DRF format)
      for (final entry in responseData.entries) {
        if (entry.value is List && (entry.value as List).isNotEmpty) {
          final formatted = _formatValue((entry.value as List).first);
          // ignore: avoid_print
          print(
              '[ErrorHandler] Found DRF list error at ${entry.key}, returning: $formatted');
          return formatted;
        }
        if (entry.value is String && (entry.value as String).isNotEmpty) {
          final formatted = _formatValue(entry.value);
          // ignore: avoid_print
          print(
              '[ErrorHandler] Found string error at ${entry.key}, returning: $formatted');
          return formatted;
        }
      }
    } else if (responseData is List && responseData.isNotEmpty) {
      final formatted = _formatValue(responseData.first);
      // ignore: avoid_print
      print('[ErrorHandler] Response is a List, returning first: $formatted');
      return formatted;
    } else if (responseData is String && responseData.isNotEmpty) {
      final formatted = _formatValue(responseData);
      // ignore: avoid_print
      print('[ErrorHandler] Response is a String, returning: $formatted');
      return formatted;
    }

    // ignore: avoid_print
    print('[ErrorHandler] Could not extract any error message');
    return null;
  }

  /// Format error value to a clean string.
  static String _formatValue(dynamic value) {
    if (value is String) {
      // Capitalize first letter if it's lowercase
      return value.isNotEmpty
          ? value[0].toUpperCase() + value.substring(1)
          : value;
    }
    return value.toString();
  }

  /// Check if an error is a validation error (contains field-level errors).
  static bool isValidationError(dynamic error) {
    if (error is! DioException || error.response == null) {
      return false;
    }
    return error.response!.statusCode == 400;
  }

  /// Check if an error is an authentication error.
  static bool isAuthError(dynamic error) {
    if (error is! DioException || error.response == null) {
      return false;
    }
    return error.response!.statusCode == 401;
  }

  /// Check if an error is a network error.
  static bool isNetworkError(dynamic error) {
    if (error is! DioException) {
      return false;
    }
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.unknown;
  }
}
