// import 'dart:async';
// import 'dart:math';

// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:zest/authentication/auth_token.dart';

// import 'auth_state.dart';
// import 'user.dart';

// typedef AsyncAuthState = AsyncValue<AuthState?>;

// final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState?>(() {
//   return AuthNotifier();
// });

// class AuthNotifier extends AsyncNotifier<AuthState?> {
//   AuthNotifier();
//   static const _key = 'token';

//   @override
//   FutureOr<AuthState?> build() async {
//     return null;
//     // final sharedPreferences = await SharedPreferences.getInstance();

//     // ref.listenSelf((_, next) {
//     //   final val = next.valueOrNull;
//     //   if (val == null) {
//     //     sharedPreferences.remove(_key);
//     //     return;
//     //   }
//     //   sharedPreferences.setString(_key, val.email);
//     // });

//     // try {
//     //   // This operation might fail for... reasons
//     //   final savedToken = sharedPreferences.getString(_key);
//     //   if (savedToken == null) return null;

//     //   // This request might also fail
//     //   return await _loginWithToken(savedToken);
//     // } catch (error, stackTrace) {
//     //   // If anything goes wrong, give a non-authenticated outcome
//     //   await sharedPreferences.remove(_key);
//     //   print(error);
//     //   print(stackTrace);
//     //   return null;
//     // }
//   }

//   // Future<AuthState?> _loginWithToken(String token) async {
//   //   // here the token should be used to perform a login request
//   //   final logInAttempt = await Future.delayed(
//   //     const Duration(milliseconds: 750),
//   //     () => Random().nextBool(),
//   //   );

//   //   // If the attempts succeeds, return the result out
//   //   if (logInAttempt) {
//   //     return const AuthState(
//   //       displayName: "My Name",
//   //       email: "My Email",
//   //       token: "some-updated-secret-auth-token",
//   //     );
//   //   }

//   //   // If the attempt fails, or returns 401, or whatever, this should fail.
//   //   throw const UnauthorizedException('401 Unauthorized or something');
//   // }

//   Future<void> logout() async {
//     // final sharedPreferences = await SharedPreferences.getInstance();

//     // // Remove the token from persistence, first
//     // await sharedPreferences.remove(_key);
//     // // No request is mocked here but I guess we could: logout
//     state = const AsyncAuthState.data(null);
//   }

//   Future<void> login(String email, String password) async {
//     // Simple mock of a successful login attempt
//     state = const AsyncLoading();
//     state = await AsyncAuthState.guard(() async {
//       return Future.delayed(
//         Duration(milliseconds: 2000),
//         () => AuthState(
//             user: User(
//               id: 1,
//               username: "David",
//               email: "dawidh@gmail.com",
//               firstName: "asdas",
//               lastName: "asds",
//             ),
//             token: AuthToken(
//               accessToken: "asds",
//               refreshToken: "asdsa",
//               accessTokenExpiration: DateTime.now(),
//               refreshTokenExpiration: DateTime.now(),
//             )),
//       );
//     });
//   }

//   bool get isAuthenticated => state.valueOrNull != null;
//   bool get isLoading => state.isLoading;
//   User? get loggedInUser => state.value?.user;
// }

// class AuthException implements Exception {
//   final String? message;
//   AuthException({this.message});
// }

// class ExpiredTokenRetryPolicy extends RetryPolicy {
//   final AuthenticationService _authService;

//   ExpiredTokenRetryPolicy(this._authService);

//   // @override
//   // int maxRetryAttempts =
//   //     10; // After this many attempts, the request would be dropped and has to be manually retried

//   @override
//   Future<bool> shouldAttemptRetryOnResponse(ResponseData response) async {
//     if (response.statusCode == 401) {
//       final token = await _authService.refreshAccessToken();
//       if (token != null && token.isValidOrCanBeRefreshed) {
//         return true;
//       } else {
//         return false;
//       }
//     }

//     return false;
//   }
// }
