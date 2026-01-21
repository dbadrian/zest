import 'package:http/http.dart' as http;
import 'package:http_interceptor/http_interceptor.dart';
import 'api_exception.dart';

/// Base interceptor interface
abstract class Interceptor<T> {
  Future<BaseRequest> onRequest(BaseRequest request) async => request;

  Future<http.Response> onResponse(http.Response response) async => response;

  Future<void> onError(ApiException error) async {}
}
