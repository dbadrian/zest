import 'package:freezed_annotation/freezed_annotation.dart';
import 'auth_token.dart';
import 'user.dart';

part 'auth_state.freezed.dart';
// part 'auth_state.g.dart';

@freezed
class AuthState with _$AuthState {
  factory AuthState({
    AuthToken? token,
    User? user,
  }) = _AuthState;

  // factory AuthState.fromJson(Map<String, dynamic> json) =>
  //     _$AuthStateFromJson(json);
}
