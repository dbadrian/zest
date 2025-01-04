import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:zest/api/api_utils.dart';
import 'package:zest/settings/settings_provider.dart';

import 'package:zest/utils/model_storage.dart';

import '../utils/networking.dart';
import 'auth_token.dart';
import 'auth_token_storage.dart';
import 'auth_state.dart';
import 'user.dart';
import 'user_storage.dart';

part 'auth_service.g.dart';

class AuthException implements Exception {
  final String? message;
  AuthException({this.message});

  @override
  String toString() {
    return message ?? "Authentication Exception";
  }
}

class ExpiredTokenRetryPolicy extends RetryPolicy {
  final AuthenticationService _authService;

  ExpiredTokenRetryPolicy(this._authService);

  // @override
  // int maxRetryAttempts =
  //     10; // After this many attempts, the request would be dropped and has to be manually retried

  @override
  Future<bool> shouldAttemptRetryOnResponse(BaseResponse response) async {
    if (response.statusCode == 401) {
      final token = await _authService.refreshAccessToken();
      if (token != null && token.isValidOrCanBeRefreshed) {
        return true;
      } else {
        return false;
      }
    }

    return false;
  }
}

class AuthenticationInterceptor extends InterceptorContract {
  final AuthenticationService _authService;
  AuthenticationInterceptor(this._authService);

  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    final token = await _authService.getToken();
    if (token == null) throw AuthException();

    final Map<String, String> headers = Map.from(request.headers);
    try {
      headers['Authorization'] = 'Bearer ${token.accessToken}';
    } catch (e) {
      developer.log(e.toString(),
          name: 'AuthenticationInterceptor.interceptRequest'); // TODO: handle?
    }

    return request.copyWith(
      headers: headers,
    );
  }

  @override
  Future<BaseResponse> interceptResponse(
      {required BaseResponse response}) async {
    if (response.statusCode == 401) {
      if (response is Response) {
        final json = jsonDecodeResponse(response);
        throw AuthException(message: json["messages"][0]["message"]);
      }
    }

    return response;
  }
}

typedef AsyncAuthState = AsyncValue<AuthState?>;

// final authProvider =
//     AsyncNotifierProvider<AuthenticationService, AuthState?>(() {
//   return AuthenticationService();
// });

// class AuthenticationService extends AsyncNotifier<AuthState?> {
@riverpod
class AuthenticationService extends _$AuthenticationService {
  // https://github.com/salomaosnff/oauth_dio/blob/master/lib/oauth_dio.dart
  // Loosely based on oauth_dio, published under MIT license

  AuthenticationService({
    ModelStorage<AuthToken>? tokenStorage,
    ModelStorage<User>? userStorage,
  })  : _tokenStorage = tokenStorage ??
            (kIsWeb // TODO: Could switch for web to securedflutterstorage eventually
                ? InMemoryAuthTokenStorage()
                : SecureAuthTokenStorage(key: "authentication_service_token")),
        _userStorage = userStorage ??
            (kIsWeb
                ? InMemoryUserStorage()
                : SecureUserStorage(key: "authentication_service_user"));

  final ModelStorage<AuthToken> _tokenStorage;
  final ModelStorage<User> _userStorage;
  late final InterceptedClient _client;

  bool get isAuthenticated => state.valueOrNull?.token != null;
  bool get isLoading => state.isLoading;
  User? get whoIsUser => state.value?.user;

  @override
  Future<AuthState?> build() async {
    state = const AsyncLoading();
    _client =
        ref.read(httpJSONClientProvider(withAuthenticationInterceptor: false));

    // Look for token in storage (will refresh if necessary)
    final token = await getTokenFromStorage();
    if (token == null) {
      debugPrint("Token not found in storage");
    }

    final user = await getUserFromStorage();
    if (user == null) {
      // something is wrong the stored state
      debugPrint("User not found in storage>");
    }

    return AuthState(user: user, token: token);
  }

  /// Checks if Token is currently valid or can be renewed.
  Future<bool> tokenIsValidOrCanBeRefreshed() async {
    AuthToken? token = await _tokenStorage.read();
    if ((token == null) || (token.isExpired && !token.canBeRefreshed)) {
      await logout();
      return false;
    } else {
      return true;
    }
  }

  /// Checks if a token is `valid` at least until end of `duration`.
  /// If token is expired, but can be renewed, it will be considered
  /// as `valid`.
  Future<bool> tokenWillBeValidIn(Duration duration) async {
    AuthToken? token = await _tokenStorage.read();

    if (token != null) {
      return DateTime.now()
          .add(duration)
          .isBefore(token.refreshTokenExpiration);
    } else {
      return false;
    }
  }

  // Future<void> safeAuthenticatedRouteSwitch(
  //     {required void Function() onRoute}) async {
  //   // Trigger a forced "logout", to ensure there wont be a
  //   // timeout during recipe editing.
  //   if (!(await tokenWillBeValidIn(SAFE_AUTH_DURATION))) {
  //     // await AuthenticationService.to.logout();
  //     openReAuthenticationDialog(
  //       onConfirm: onRoute,
  //     );
  //   } else {
  //     onRoute();
  //   }
  // }

  /// Checks if a valid or renewable token is in the storage
  /// If no Token is found or can't be renewed, force performs logout
  Future<AuthToken?> getTokenFromStorage() async {
    AuthToken? token = await _tokenStorage.read();
    debugPrint(token.toString());
    return validateOrRefreshToken(token);
  }

  /// Checks if a user is in the storage
  /// This should always be the case. If valid token is found, but no user
  /// We perform a force logout.
  Future<User?> getUserFromStorage() async {
    final user = await _userStorage.read();
    if (user == null) {
      debugPrint("User not found in storage: $user");
      await logout();
      // return null;
    }
    return user;

    // if (isAuthenticated) {
    // } else {
    //   return null;
    // }
  }

  /// Gets the currently in-memory stored token, validated and optionally
  /// refreshes it
  Future<AuthToken?> getToken() {
    return validateOrRefreshToken(state.value?.token);
  }

  /// Helper to check validity of token and attempts to refresh if necessary
  /// and possible
  Future<AuthToken?> validateOrRefreshToken(AuthToken? token) async {
    if (token == null) {
      debugPrint("No token found. Running logout routine");
      // Not token store -> no longer authenticated with still
      await logout();
      return null;
    } else if (!token.isExpired) {
      // state = AsyncValue.data(AuthState(token: token));
      return token;
    } else if (token.canBeRefreshed) {
      debugPrint("Token can be refreshed");
      final token = await refreshAccessToken();
      if (token != null) {
        state = AsyncValue.data(state.value!.copyWith(token: token));
      }
      return token;
    } else {
      // Found token but expired and cant be refreshed
      await logout();
      return null;
    }
  }

  Future<bool> login(String username, String password) async {
    final SettingsState settings = ref.read(settingsProvider);
    final url = getAPIUrl(settings, '/auth/login/');
    state = const AsyncLoading();
    try {
      final response = await postWithRedirects(
        _client,
        url,
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode == 400) {
        // bad request
        // wrong login data
        // missing login data (can actually capture the reponse!)
        await logout();
        return false;
      } else if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final user = User.fromJson(body["user"]);
        await _userStorage.save(user);
        debugPrint(body.toString());
        final token = AuthToken.fromJson(body);
        await _tokenStorage.save(token);
        state = AsyncAuthState.data(AuthState(token: token, user: user));
        return true;
      } else {
        // TODO: better handling
        throw "unexpected statusCode: ${response.statusCode}";
      }
    } on SocketException catch (e, stackTrace) {
      state = AsyncError(
          ServerNotReachableException(
              message: "Server couldn't be reached! (${e.message})"),
          stackTrace);
    } on ClientException catch (e, stackTrace) {
      state = AsyncError(
          ServerNotReachableException(
              message: "Server couldn't be reached! (${e.message})"),
          stackTrace);
    } on TimeoutException catch (e, stackTrace) {
      state = AsyncError(
          ServerNotReachableException(
              message: "Server couldn't be reached! (${e.message})"),
          stackTrace);
    } on BadRequestException catch (e, stackTrace) {
      // Most likely a incorrect login
      state = AsyncError(
          AuthException(
              message: "Incorrect login credentials. "), //(${e.message})
          stackTrace);
    } catch (e, stacktrace) {
      developer.log('Exception: ${e.toString()}');
      developer.log('Stacktrace: ${stacktrace.toString()}');
    }

    return false;
  }

  Future<void> logout() async {
    // Clear all user data in memory and storage
    // state = const AsyncAuthState.data(null);
    state = AsyncAuthState.data(state.value?.copyWith(token: null));
    await _tokenStorage.clear();
    debugPrint((await _userStorage.read()).toString());
    // We do  not! have to evict the user data
    // let the user fix this themselves...
  }

  Future<AuthToken?> refreshAccessToken({AuthToken? token}) async {
    final token_ = token ?? await _tokenStorage.read();
    if (token_ == null || !token_.canBeRefreshed) {
      debugPrint("Token is null or can't be refreshed");
      return null;
    }

    final SettingsState settings = ref.read(settingsProvider);
    final url = getAPIUrl(settings, '/auth/token/refresh/');
    final response = await postWithRedirects(_client, url,
        body: jsonEncode({'refresh': token_.refreshToken}));

    if (response.statusCode == 200) {
      try {
        final json = jsonDecodeResponse(response);
        final newToken = token_.copyWith(
          accessToken: json[
              'access'], // TODO: why the fuck does djrest ath/simplejwt not call this access_token
          accessTokenExpiration: DateTime.parse(json['access_expiration']),
        );

        await _tokenStorage.save(newToken);

        final user = await _userStorage.read();
        debugPrint("Upon refresh (user): $user");

        // TODO: Why does copyWith not exist for the AuthToken class?
        state = AsyncAuthState.data(
            AuthState(token: newToken, user: state.value?.user));

        return newToken;
      } on InvalidJSONDataException {
        // TODO: Handle this in another way?
        await logout();
        return null;
      }
    } else if (response.statusCode == 401) {
      // There was a refresh token, but its now invalid
      await logout();
      return null;
    } else {
      // TODO: Actual error
      throw "Unexpected error in AuthService occured";
    }
  }
}
