import '../utils/model_storage.dart';
import 'auth_token.dart';

class InMemoryAuthTokenStorage extends InMemoryModelStorage<AuthToken> {}

class SecureAuthTokenStorage extends SecureModelStorage<AuthToken> {
  SecureAuthTokenStorage({required super.key});

  @override
  AuthToken fromJson(Map<String, dynamic> json) {
    return AuthToken.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(AuthToken instance) {
    return instance.toJson();
  }
}
