// class AuthenticationInterceptor extends InterceptorContract {
//   final AuthenticationService _authService;
//   AuthenticationInterceptor(this._authService);

//   @override
//   Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
//     final token = await _authService.getToken();
//     if (token == null) throw AuthException();

//     final Map<String, String> headers = Map.from(request.headers);
//     try {
//       headers['Authorization'] = 'Bearer ${token.accessToken}';
//     } catch (e) {
//       developer.log(e.toString(),
//           name: 'AuthenticationInterceptor.interceptRequest'); // TODO: handle?
//     }

//     return request.copyWith(
//       headers: headers,
//     );
//   }

//   @override
//   Future<BaseResponse> interceptResponse(
//       {required BaseResponse response}) async {
//     if (response.statusCode == 401) {
//       if (response is Response) {
//         final json = jsonDecodeResponse(response);
//         throw AuthException(message: json["messages"][0]["message"]);
//       }
//     }

//     return response;
//   }
// }
