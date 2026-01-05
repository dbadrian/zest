import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:zest/core/network/api_exception.dart';
import 'package:zest/core/network/interceptor.dart';

class AuthInterceptor extends Interceptor {
  final Future<String?> Function() getAccessToken;
  final Future<void> Function() refreshToken;
  final Future<void> Function() onUnauthorized;

  bool _isRefreshing = false;

  AuthInterceptor({
    required this.getAccessToken,
    required this.refreshToken,
    required this.onUnauthorized,
  });

  @override
  Future<http.Request> onRequest(http.Request request) async {
    final token = await getAccessToken();

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    return request;
  }

  @override
  Future<void> onError(ApiException error) async {
    debugPrint("auth error.. $_isRefreshing");
    // Handle unauthorized errors
    if (error.type == ApiErrorType.unauthorized && !_isRefreshing) {
      _isRefreshing = true;
      debugPrint("Trying to refresh");
      try {
        // Try to refresh the token
        await refreshToken();
        // Token refreshed successfully, the request will be retried
      } catch (e) {
        // Refresh failed, user needs to login again
        await onUnauthorized();
      } finally {
        _isRefreshing = false;
      }
    }
  }
}
