import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_token.freezed.dart';
part 'auth_token.g.dart';

@freezed
// @JsonSerializable(explicitToJson: true)
class AuthToken with _$AuthToken {
  const AuthToken._();
  factory AuthToken({
    @JsonKey(name: "access") required String accessToken,
    @JsonKey(name: "refresh") required String refreshToken,
    @JsonKey(name: "access_expiration") required DateTime accessTokenExpiration,
    @JsonKey(name: "refresh_expiration")
    required DateTime refreshTokenExpiration,
  }) = _AuthToken;

  bool get isExpired => DateTime.now().isAfter(accessTokenExpiration);

  bool get canBeRefreshed => DateTime.now().isBefore(refreshTokenExpiration);

  bool get isValidOrCanBeRefreshed => !isExpired || canBeRefreshed;

  @override
  String toString() {
    return 'AuthToken{\naccess_token:$accessToken,\nrefresh_token:$refreshToken,\nexpires_in:$accessTokenExpiration,\nrefreshable_till:$refreshTokenExpiration';
  }

  factory AuthToken.fromJson(Map<String, dynamic> json) =>
      _$AuthTokenFromJson(json);
  // Map<String, dynamic> toJson() => _$AuthTokenToJson(this);
}
