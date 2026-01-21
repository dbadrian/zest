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
    if (response is Response) {
      developer.log('Status: ${response.statusCode}\nBody: ${response.body}',
          name: 'LoggingInterceptor.interceptResponse');
    } else if (response is StreamedResponse) {
      developer.log(
          'Status: ${response.statusCode}\nStreamed response (body not available)',
          name: 'LoggingInterceptor.interceptResponse');
    }
    return response;
  }
}
