import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http_interceptor/http_interceptor.dart';

class InvalidJSONDataException implements Exception {
  final String? message;
  InvalidJSONDataException({this.message});
}

Map<String, dynamic> jsonDecodeResponseData(Response data) {
  final contentType = data.headers["content-type"];
  if (contentType != null && contentType == "application/json") {
    return jsonDecode(utf8.decode(data.bodyBytes));
  }
  throw InvalidJSONDataException(
      message: "Response appears not to be JSON data (according to header)");
}

/// Decode http.Respose that contains Json data. Raises Exception if data
/// is not valid Json or doesn't contain Json
Map<String, dynamic> jsonDecodeResponse(http.Response data) {
  final contentType = data.headers["content-type"];
  // debugPrint(utf8.decode(data.bodyBytes));
  // debugPrint(contentType);

  if (contentType != null &&
      (contentType == "application/json" ||
          contentType == "application/json; charset=utf-8")) {
    return jsonDecode(utf8.decode(data.bodyBytes));
  }
  throw InvalidJSONDataException(
      message: "Response appears not to be JSON data (according to header)");
}

/// Response handler that does basic decoding and error handling for http
/// request
///
/// TODO: HIGH HIGH HIGH DEPRECATE
Future<T> genericResponseHandler<T>(
    {required Future<http.Response> Function() requestCallback,
    required T Function(Map<String, dynamic>) create}) async {
  try {
    final response = await requestCallback();
    final json = jsonDecodeResponse(response);
    return create(json);
    // Handle various timout/lack of internet exceptions uniformly...
  } on SocketException catch (e) {
    throw ServerNotReachableException(
        // TODO: better error message (could also be no internet!?)
        message: "Server couldn't be reached! (${e.message})");
  } on http.ClientException catch (e) {
    throw ServerNotReachableException(
        message: "Server couldn't be reached! (${e.message})");
  } on TimeoutException catch (e) {
    throw ServerNotReachableException(
        message: "Server couldn't be reached! Timeout.(${e.message})");
  }
  // propagate other exceptions.
}

class ServerNotReachableException implements Exception {
  final String? message;
  ServerNotReachableException({this.message});

  @override
  String toString() {
    return message ?? "Server not reachable";
  }
}

class ResourceNotFoundException implements Exception {
  final String? message;
  ResourceNotFoundException({this.message});
}

class ResourceNotFoundInterceptor extends InterceptorContract {
  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async =>
      request;

  @override
  Future<BaseResponse> interceptResponse(
      {required BaseResponse response}) async {
    // if (response.statusCode == 404) {
    //   if (response is Response) {
    //     final ret = jsonDecodeResponseData(response);
    //     throw ResourceNotFoundException(message: ret.toString());
    //   }
    // }

    switch (response.statusCode) {
      case 404:
        throw ResourceNotFoundException();
      case 401:
        throw NotAuthorizedException();
      case 400:
        throw BadRequestException();
      case 500:
        throw ServerNotReachableException(); // "Internal Server Error [500]"
    }
    return response;
  }
}

class BadRequestException implements Exception {
  final Map<String, dynamic>? message;
  BadRequestException({this.message});
}

class BadRequestInterceptor extends InterceptorContract {
  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async =>
      request;

  @override
  Future<BaseResponse> interceptResponse(
      {required BaseResponse response}) async {
    if (response.statusCode == 400) {
      if (response is Response) {
        final ret = jsonDecodeResponseData(response);
        throw BadRequestException(message: ret);
      }
    }
    return response;
  }
}

class NotAuthorizedException implements Exception {
  final String? message;
  NotAuthorizedException({this.message});
}

class NotAuthorizedInterceptor extends InterceptorContract {
  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async =>
      request;

  @override
  Future<BaseResponse> interceptResponse(
      {required BaseResponse response}) async {
    if (response.statusCode == 401) {
      if (response is Response) {
        final ret = jsonDecodeResponseData(response);
        throw NotAuthorizedException(message: ret.toString());
      }
    }
    return response;
  }
}

void openServerNotAvailableDialog(BuildContext context,
    {void Function()? onPressed, String? title, String? content}) {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title ?? 'Server unreachable!'),
        content: Text(content ??
            "Sorry, server can't be reached at the moment.\n\n"
                "Please try again in a moment."),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
            child: const Text("Okay... I'll wait a moment!"),
            onPressed: () {
              if (onPressed != null) {
                onPressed();
              }

              if (context.mounted) {
                GoRouter.of(context).pop();
              }
            },
          ),
        ],
      );
    },
  );
}

Future<http.Response> postWithRedirects(
  InterceptedClient client,
  Uri uri, {
  Object? body,
  Map<String, String>? headers,
  int maxRedirects = 5,
}) async {
  var currentResponse = await client.post(uri, headers: headers, body: body);

  int redirectCount = 0;
  while ((currentResponse.statusCode == 301 ||
          currentResponse.statusCode == 302) &&
      currentResponse.headers.containsKey('location') &&
      redirectCount < maxRedirects) {
    debugPrint("Redirecting to: ${currentResponse.headers['location']}");
    final redirectUrl = currentResponse.headers['location'];
    if (redirectUrl == null) break;

    uri = Uri.parse(redirectUrl);
    currentResponse =
        await postWithRedirects(client, uri, headers: headers, body: body);
    redirectCount++;
  }

  return currentResponse;
}
// // abstract class Response<T> {}

// // class Success<T> extends Response<T> {
// //   final T value;

// //   Success(this.value);
// // }

// // class Error<T> extends Response<T> {
// //   final Exception exception;

// //   Error(this.exception);
// // }

// // class ModelConverter<T> {
// //   @override
// //   Request convertRequest(Request request) {
// //     final req = applyHeader(
// //       request,
// //       contentTypeKey,
// //       jsonHeaders,
// //       override: false,
// //     );

// //     return encodeJson(req);
// //   }

// //   Request encodeJson(Request request) {
// //     final contentType = request.headers[contentTypeKey];
// //     if (contentType != null && contentType.contains(jsonHeaders)) {
// //       return request.copyWith(body: json.encode(request.body));
// //     }
// //     return request;
// //   }

// //   Response<BodyType> decodeJson<BodyType, InnerType>(Response response) {
// //     final contentType = response.headers[contentTypeKey];
// //     var body = response.body;
// //     if (contentType != null && contentType.contains(jsonHeaders)) {
// //       body = utf8.decode(response.bodyBytes);
// //     }
// //     try {
// //       final mapData = json.decode(body);
// //       if (mapData['status'] != null) {
// //         return response.copyWith<BodyType>(
// //             body: Error(Exception(mapData['status'])) as BodyType);
// //       }
// //       final recipeQuery = APIRecipeQuery.fromJson(mapData);
// //       return response.copyWith<BodyType>(
// //           body: Success(recipeQuery) as BodyType);
// //     } catch (e) {
// //       chopperLogger.warning(e);
// //       return response.copyWith<BodyType>(
// //           body: Error(e as Exception) as BodyType);
// //     }
// //   }

// //   @override
// //   Response<BodyType> convertResponse<BodyType, InnerType>(Response response) {
// //     return decodeJson<BodyType, InnerType>(response);
// //   }
// // }
