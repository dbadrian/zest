import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../interceptor.dart';
import '../api_exception.dart';

/// Interceptor for logging requests and responses (debug only)
class LoggingInterceptor extends Interceptor {
  final bool enabled;

  LoggingInterceptor({this.enabled = true});

  @override
  Future<http.Request> onRequest(http.Request request) async {
    if (enabled) {
      debugPrint('→ ${request.method} ${request.url}');
      debugPrint('  Headers: ${request.headers}');
      if (request.body.isNotEmpty) {
        debugPrint('  Body: ${request.body}');
      }
    }
    return request;
  }

  @override
  Future<http.Response> onResponse(http.Response response) async {
    if (enabled) {
      debugPrint('← ${response.statusCode} ${response.request?.url}');
      if (response.body.isNotEmpty && response.body.length < 1000) {
        debugPrint('  Body: ${response.body}');
      }
    }
    return response;
  }

  @override
  Future<void> onError(ApiException error) async {
    if (enabled) {
      debugPrint('✗ Error: ${error.message} (${error.type})');
      if (error.originalError != null) {
        debugPrint('  Original: ${error.originalError}');
      }
    }
  }
}
