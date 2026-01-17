import '../utils/persistance.dart';
import 'auth_state.dart';

class InMemoryAuthStateStorage extends InMemoryModelStorage<AuthState> {}

class SecureAuthStateStorage extends SecureModelStorage<AuthState> {
  SecureAuthStateStorage({required super.key, required super.storage});

  @override
  AuthState fromJson(Map<String, dynamic> json) {
    return AuthState.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(AuthState instance) {
    return instance.toJson();
  }
}
