import 'package:dio/dio.dart';

/// Normalized API failure.
///
/// Mirrors the error contract the food-ordering web client already relies on
/// (`services/http.ts`): a numeric status plus a human-readable message that
/// prefers the backend's own `message`/`error` field. Status `0` means the
/// request never reached the server.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.errors,
  });

  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  /// Network unreachable, DNS failure, or timeout — safe to retry.
  bool get isNetworkError => statusCode == 0;

  /// Token missing, expired or rejected — the caller should re-authenticate.
  bool get isAuthError => statusCode == 401;

  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          statusCode: 0,
          message: 'Request timed out. Please check your connection.',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const ApiException(
          statusCode: 0,
          message: 'Network error. Please check your connection and try again.',
        );
      case DioExceptionType.cancel:
        return const ApiException(statusCode: 0, message: 'Request cancelled.');
      case DioExceptionType.badCertificate:
        return const ApiException(
          statusCode: 0,
          message: 'Could not establish a secure connection.',
        );
      case DioExceptionType.badResponse:
        break;
    }

    final response = error.response;
    final status = response?.statusCode ?? 0;
    final data = response?.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final message = map['message'] ?? map['error'];
      return ApiException(
        statusCode: status,
        message: message is String && message.trim().isNotEmpty
            ? message
            : 'Request failed with status $status',
        errors: map['errors'] is Map
            ? Map<String, dynamic>.from(map['errors'] as Map)
            : null,
      );
    }
    return ApiException(
      statusCode: status,
      message: 'Request failed with status $status',
    );
  }

  @override
  String toString() => message;
}
