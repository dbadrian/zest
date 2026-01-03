import 'package:http/http.dart' as http;
import 'api_exception.dart';

/// Base interceptor interface
abstract class Interceptor {
  Future<http.Request> onRequest(http.Request request) async => request;

  Future<http.Response> onResponse(http.Response response) async => response;

  Future<void> onError(ApiException error) async {}
}
