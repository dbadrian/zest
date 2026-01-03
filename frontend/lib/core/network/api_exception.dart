import 'package:http/http.dart' as http;
import 'dart:convert';

/// API exception types
enum ApiErrorType {
  network, // No internet, DNS failure
  timeout, // Request timeout
  toomanyredirects,
  invalidjson,
  badrequest, // 400
  unauthorized, // 401
  forbidden, // 403
  notFound, // 404
  server, // 5xx
  validation, // 422
  unknown,
}

class ApiException implements Exception {
  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final dynamic originalError;
  final Map<String, dynamic>? details;

  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.originalError,
    this.details,
  });

  factory ApiException.network({
    required String message,
    Object? originalError,
  }) {
    return ApiException(
      type: ApiErrorType.network,
      message: message,
      originalError: originalError,
    );
  }

  factory ApiException.timeout({
    required String message,
    Object? originalError,
  }) {
    return ApiException(
      type: ApiErrorType.timeout,
      message: message,
      originalError: originalError,
    );
  }

  factory ApiException.invalidjson({
    required String message,
    Object? originalError,
  }) {
    return ApiException(
      type: ApiErrorType.invalidjson,
      message: message,
      originalError: originalError,
    );
  }

  factory ApiException.toomanyredirects({
    required String message,
    Object? originalError,
  }) {
    return ApiException(
      type: ApiErrorType.toomanyredirects,
      message: message,
      originalError: originalError,
    );
  }

  factory ApiException.fromResponse(http.Response response) {
    final statusCode = response.statusCode;
    Map<String, dynamic>? details;
    String message = 'Request failed';

    try {
      if (response.body.isNotEmpty) {
        details = jsonDecode(response.body);
        message = details?['detail']?.toString() ??
            details?['message']?.toString() ??
            message;
      }
    } catch (_) {
      // Ignore JSON parse errors
    }

    final type = switch (statusCode) {
      400 => ApiErrorType.badrequest,
      401 => ApiErrorType.unauthorized,
      403 => ApiErrorType.forbidden,
      404 => ApiErrorType.notFound,
      422 => ApiErrorType.validation,
      >= 500 => ApiErrorType.server,
      _ => ApiErrorType.unknown,
    };

    return ApiException(
      type: type,
      message: message,
      statusCode: statusCode,
      details: details,
    );
  }

  bool get isNetworkError => type == ApiErrorType.network;
  bool get isTimeout => type == ApiErrorType.timeout;
  bool get isOffline => isNetworkError || isTimeout;

  @override
  String toString() => 'ApiException($type): $message';
}
