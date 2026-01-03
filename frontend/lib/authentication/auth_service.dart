import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:zest/api/api_utils.dart';
import 'package:zest/core/network/api_exception.dart';
import 'package:zest/core/network/http_client.dart';
import 'package:zest/core/network/interceptors/logging_interceptor.dart';
import 'package:zest/settings/settings_provider.dart';

import 'package:zest/utils/model_storage.dart';

import '../utils/networking.dart';
import 'auth_state.dart';
import 'auth_state_storage.dart';
import 'user.dart';
import 'user_storage.dart';

part 'auth_service.g.dart';

typedef AsyncAuthState = AsyncValue<AuthState?>;

@riverpod
class AuthenticationService extends _$AuthenticationService {
  AuthenticationService({
    ModelStorage<AuthState>? tokenStorage,
  }) : _authStorage = tokenStorage ??
            SecureAuthStateStorage(key: "authentication_service_token");

  final ModelStorage<AuthState> _authStorage;
  late final ApiHttpClient _client;

  bool get isAuthenticated => state.hasValue && state.value != null;
  bool get isLoading => state.isLoading;
  User? get whoIsUser => state.valueOrNull?.user;

  @override
  Future<AuthState?> build() async {
    // state = const AsyncLoading();
    final settings = ref.read(settingsProvider);
    _client = ApiHttpClient(baseUrl: settings.current.apiUrl);
    _client.addInterceptor(LoggingInterceptor(enabled: true));

    // Auto cancelation of requests
    ref.onDispose(() {
      _client.dispose();
    });

    // Look for token in storage (will refresh if necessary)

    final _state = await _authStorage.read();
    debugPrint(_state.toString());

    if (_state == null) {
      debugPrint("AuthState not found in storage");
    }
    return _state;
  }

  /// Checks if access is still valid.
  Future<bool> tokenWillBeValidIn(Duration duration) async {
    AuthState? authState = state.valueOrNull;

    if (authState != null && !authState.isExpired) {
      // isExpired can only be True if expiresAt is not null. and if its anyway
      // expired already, it certainly will be in the future
      return DateTime.now().add(duration).isBefore(authState.expiresAt!);
    } else {
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    state = const AsyncLoading();
    await _authStorage.clear(); // clear if not already cleared

    final loginResponse = await _client.post<AuthResponse>(
        "/auth/login", AuthResponse.fromJson,
        encodeJson: false,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          'username': username,
          'password': password
        });
    // body: jsonEncode({'username': username, 'password': password}));

    // whatever is wrong...early abort
    if (loginResponse.isFailure) {
      state = AsyncError(loginResponse.errorOrNull!, StackTrace.current);
      return false;
    }

    final _authState = loginResponse.dataOrNull!;

    // since it was a success, we can now query for the user credentials
    final userResponse = await _client.get<User>("/auth/me", User.fromJson,
        headers: {'Authorization': 'Bearer ${_authState.accessToken}'});

    if (userResponse.isFailure) {
      state = AsyncError(userResponse.errorOrNull!, StackTrace.current);
      return false;
    }

    final newState = AuthState(
        accessToken: _authState.accessToken,
        refreshToken: _authState.refreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: _authState.expiresIn)),
        user: userResponse.dataOrNull!);
    await _authStorage.save(newState);
    state = AsyncData(newState);
    return true;
  }

  Future<bool> refreshToken() async {
    final oldState = state.valueOrNull;
    if (oldState == null) {
      await _authStorage.clear();
      return false;
    }

    final refreshResponse = await _client.post<AuthResponse>(
        "/auth/refresh", AuthResponse.fromJson,
        body: {'refresh_token': oldState.refreshToken});

    // whatever is wrong...early abort
    if (refreshResponse.isFailure) {
      await _authStorage.clear();
      state = AsyncError(refreshResponse.errorOrNull!, StackTrace.current);
      return false;
    }

    final _authState = refreshResponse.dataOrNull!;
    final newState = oldState.copyWith(
        accessToken: _authState.accessToken,
        refreshToken: _authState.refreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: _authState.expiresIn)));
    await _authStorage.save(newState);
    state = AsyncData(newState);
    return true;
  }

  Future<void> logout() async {
    if (!state.hasValue) {
      return; // nothing to do
    }
    await _authStorage.clear();
    state = AsyncData(null);
  }
}
