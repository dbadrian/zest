import 'dart:async';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/core/network/http_client.dart';
import 'package:zest/core/network/interceptors/logging_interceptor.dart';
import 'package:zest/core/providers/http_client_provider.dart';
import 'package:zest/settings/settings_provider.dart';

import 'package:zest/utils/persistance.dart';

import 'auth_state.dart';
import 'auth_state_storage.dart';
import 'user.dart';

part 'auth_service.g.dart';

typedef AsyncAuthState = AsyncValue<AuthState?>;

// ignore: constant_identifier_names
const LAST_USER_KEY = "key_auth_last_user";

@riverpod
class AuthenticationService extends _$AuthenticationService {
  AuthenticationService({
    ModelStorage<AuthState>? tokenStorage,
  });

  late String? _lastUser;
  late final FlutterSecureStorage _storage;

  late final ModelStorage<AuthState> _authStorage;

  bool get isAuthenticated => state.hasValue && state.value != null;
  bool get isLoading => state.isLoading;
  User? get whoIsUser => state.valueOrNull?.user;
  String? get lastUser => _lastUser;

  @override
  Future<AuthState?> build() async {
    _storage = ref.read(secureStorageProvider);
    _authStorage = SecureAuthStateStorage(
        key: "authentication_service_token", storage: _storage);

    _lastUser = await _storage.read(key: LAST_USER_KEY);

    return _loadStateFromStorage();
  }

  Future<AuthState?> _loadStateFromStorage() async {
    final state = await _authStorage.read();
    debugPrint(state.toString());

    if (state == null) {
      debugPrint("AuthState not found in storage");
    }
    return state;
  }

  /// Checks if access is still valid.
  Future<bool> tokenWillBeValidIn(Duration duration) async {
    AuthState? authState = state.valueOrNull;

    if (authState != null && !authState.isExpired) {
      // isExpired can only be True if expiresAt is not null. and if its anyway
      // expired already, it certainly will be in the future
      return DateTime.now().add(duration).isBefore(authState.expiresAt);
    } else {
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    state = const AsyncLoading();
    _lastUser = username;
    await _storage.write(key: LAST_USER_KEY, value: _lastUser);
    debugPrint("Clearing existing auth storage");
    await _authStorage.clear(); // clear if not already cleared

    final loginResponse = await ref
        .read(apiClientProvider(withAuthentication: false))
        .post<AuthResponse>("/auth/login", AuthResponse.fromJson,
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

    final authState = loginResponse.dataOrNull!;

    // since it was a success, we can now query for the user credentials
    final userResponse = await ref
        .read(apiClientProvider(withAuthentication: false))
        .get<User>("/auth/me", User.fromJson,
            headers: {'Authorization': 'Bearer ${authState.accessToken}'});

    if (userResponse.isFailure) {
      state = AsyncError(userResponse.errorOrNull!, StackTrace.current);
      return false;
    }

    final newState = AuthState(
        accessToken: authState.accessToken,
        refreshToken: authState.refreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: authState.expiresIn)),
        user: userResponse.dataOrNull!);
    await _authStorage.save(newState);
    state = AsyncData(newState);
    return true;
  }

  Future<bool> refreshToken() async {
    final oldState = state.valueOrNull ?? await _loadStateFromStorage();
    if (oldState == null) {
      debugPrint("Clearing auth storage as state is reported null");
      await _authStorage.clear();
      return false;
    }

    final refreshResponse = await ref
        .read(apiClientProvider(withAuthentication: false))
        .post<AuthResponse>("/auth/refresh", AuthResponse.fromJson,
            body: {'refresh_token': oldState.refreshToken});

    // whatever is wrong...early abort
    if (refreshResponse.isFailure) {
      debugPrint(refreshResponse.errorOrNull.toString());
      // await _authStorage.clear(); // TODO: HIGH: should we wipe on an error or accept it?
      state = AsyncError(refreshResponse.errorOrNull!, StackTrace.current);
      return false;
    }

    final authState = refreshResponse.dataOrNull!;
    final newState = oldState.copyWith(
        accessToken: authState.accessToken,
        refreshToken: authState.refreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: authState.expiresIn)));
    debugPrint("Got a new state: $newState");
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
