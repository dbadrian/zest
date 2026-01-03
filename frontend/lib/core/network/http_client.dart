import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'interceptor.dart';
import 'api_response.dart';
import 'api_exception.dart';

part 'http_client.g.dart';

dynamic jsonDecodeResponse(http.Response data) {
  final contentType = data.headers["content-type"];
  // debugPrint(utf8.decode(data.bodyBytes));
  // debugPrint(contentType);

  if (contentType != null &&
      (contentType == "application/json" ||
          contentType == "application/json; charset=utf-8")) {
    return jsonDecode(utf8.decode(data.bodyBytes));
  }
  throw ApiException.invalidjson(
      message: "Response appears not to be JSON data (according to header)");
}

/// Custom HTTP client with interceptor support
class ApiHttpClient {
  final String baseUrl;
  final List<Interceptor> _interceptors = [];
  final http.Client _client;

  static const Duration defaultTimeout = Duration(seconds: 10);
  static const int maxRetries = 3;

  ApiHttpClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  void addInterceptor(Interceptor interceptor) {
    _interceptors.add(interceptor);
  }

  Future<ApiResponse<T>> get<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
  }) async {
    return _request<T>(
        method: 'GET',
        path: path,
        headers: headers,
        queryParams: queryParams,
        timeout: timeout,
        fromJson: fromJson);
  }

  Future<ApiResponse<T>> post<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  }) async {
    return _request<T>(
        method: 'POST',
        path: path,
        headers: headers,
        body: body,
        timeout: timeout,
        fromJson: fromJson);
  }

  Future<ApiResponse<T>> put<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  }) async {
    return _request<T>(
        method: 'PUT',
        path: path,
        headers: headers,
        body: body,
        timeout: timeout,
        fromJson: fromJson);
  }

  Future<ApiResponse<T>> _request<T>(
      {required String method,
      required String path,
      required T Function(Map<String, dynamic>) fromJson,
      Map<String, String>? headers,
      Map<String, dynamic>? queryParams,
      dynamic body,
      Duration? timeout,
      int retryCount = 0,
      int maxRedirects = 5,
      String? absoluteUrl}) async {
    try {
      // Build URL
      Uri uri;
      if (absoluteUrl != null) {
        // mostly used when a redirect happened!
        uri = Uri.parse(absoluteUrl);
        if (queryParams != null && queryParams.isNotEmpty) {
          uri.replace(
            queryParameters: queryParams.map(
              (key, value) => MapEntry(key, value.toString()),
            ),
          );
        }
      } else {
        uri = _buildUri(path, queryParams);
      }

      // Build initial request
      var request = http.Request(method, uri);
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?headers,
      });

      if (body != null) {
        request.body = jsonEncode(body);
      }

      // Run request interceptors
      for (final interceptor in _interceptors) {
        request = await interceptor.onRequest(request);
      }

      // Execute request with timeout
      final streamedResponse =
          await _client.send(request).timeout(timeout ?? defaultTimeout);

      final response = await http.Response.fromStream(streamedResponse);

      // Run response interceptors
      var processedResponse = response;
      for (final interceptor in _interceptors) {
        processedResponse = await interceptor.onResponse(processedResponse);
      }

      // Handle response
      if (processedResponse.statusCode >= 200 &&
          processedResponse.statusCode < 300) {
        final decoded = jsonDecodeResponse(processedResponse);
        return ApiResponse.success(
          data: fromJson(decoded),
          statusCode: processedResponse.statusCode,
          headers: processedResponse.headers,
        );
      } else if (processedResponse.statusCode >= 301 &&
          processedResponse.statusCode < 303) {
        if (maxRetries == 0) {
          throw ApiException.toomanyredirects(
              message: "Encountered too many redirects, terminating.");
        }
        // handle 301 and 302 redirects
        debugPrint("Redirecting to: ${processedResponse.headers['location']}");
        final redirectUrl = processedResponse.headers['location'];
        if (redirectUrl == null) {
          throw ApiException.toomanyredirects(
              message: "Redirected, but invalid url.");
        }

        return _request<T>(
            method: method,
            path: path,
            fromJson: fromJson,
            headers: headers,
            queryParams: queryParams,
            body: body,
            timeout: timeout,
            maxRedirects: maxRedirects - 1,
            absoluteUrl: redirectUrl);
      } else {
        throw ApiException.fromResponse(processedResponse);
      }
    } on TimeoutException catch (e) {
      // Retry on timeout
      if (retryCount < maxRetries && method == 'GET') {
        await Future.delayed(Duration(seconds: (retryCount + 1) * 2));
        return _request<T>(
          method: method,
          path: path,
          fromJson: fromJson,
          headers: headers,
          queryParams: queryParams,
          body: body,
          timeout: timeout,
          retryCount: retryCount + 1,
        );
      }

      final error = ApiException.timeout(
        message: 'Request timed out after ${timeout ?? defaultTimeout}',
        originalError: e,
      );

      // Run error interceptors
      for (final interceptor in _interceptors) {
        await interceptor.onError(error);
      }

      return ApiResponse.failure(error);
    } on ApiException catch (e) {
      // Run error interceptors
      for (final interceptor in _interceptors) {
        await interceptor.onError(e);
      }

      return ApiResponse.failure(e);
    } catch (e) {
      // Network error (offline, DNS failure, etc.)
      final error = ApiException.network(
        message: 'Network error: ${e.toString()}',
        originalError: e,
      );

      // Run error interceptors
      for (final interceptor in _interceptors) {
        await interceptor.onError(error);
      }

      return ApiResponse.failure(error);
    }
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParams) {
    final uri = Uri.parse('$baseUrl$path');

    if (queryParams == null || queryParams.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: queryParams.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  void dispose() {
    _client.close();
  }
}

// @Riverpod(keepAlive: true)
// ApiHttpClient apiClient(Ref ref) {
//   const baseUrl = String.fromEnvironment(
//     'API_BASE_URL',
//     defaultValue: 'http://localhost:8000',
//   );

//   final client = ApiHttpClient(baseUrl: baseUrl);

//   // // Add auth interceptor
//   // client.addInterceptor(
//   //   AuthInterceptor(
//   //     getAccessToken: () async {
//   //       final authState = ref.read(authStateProvider);
//   //       return authState?.accessToken;
//   //     },
//   //     refreshToken: () async {
//   //       await ref.read(authStateProvider.notifier).refreshToken();
//   //     },
//   //     onUnauthorized: () async {
//   //       await ref.read(authStateProvider.notifier).logout();
//   //     },
//   //   ),
//   // );

//   // // Add logging in debug mode
//   // client.addInterceptor(
//   //   LoggingInterceptor(
//   //     enabled: const bool.fromEnvironment('dart.vm.product') == false,
//   //   ),
//   // );

//   ref.onDispose(() => client.dispose());

//   return client;
// }
