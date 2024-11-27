import 'dart:developer' as developer;

import 'package:http_interceptor/http_interceptor.dart';

class LoggingInterceptor extends InterceptorContract {
  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    developer.log(request.toString(),
        name: 'LoggingInterceptor.interceptRequest');
    return request;
  }

  @override
  Future<BaseResponse> interceptResponse(
      {required BaseResponse response}) async {
    developer.log(response.toString(),
        name: 'LoggingInterceptor.interceptResponse');
    return response;
  }
}
