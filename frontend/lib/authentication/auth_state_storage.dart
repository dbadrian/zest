import '../utils/model_storage.dart';
import 'auth_state.dart';

class InMemoryAuthStateStorage extends InMemoryModelStorage<AuthState> {}

class SecureAuthStateStorage extends SecureModelStorage<AuthState> {
  SecureAuthStateStorage({required super.key});

  @override
  AuthState fromJson(Map<String, dynamic> json) {
    return AuthState.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(AuthState instance) {
    return instance.toJson();
  }
}
