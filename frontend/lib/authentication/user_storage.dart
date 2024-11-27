import '../utils/model_storage.dart';
import 'user.dart';

class InMemoryUserStorage extends InMemoryModelStorage<User> {}

class SecureUserStorage extends SecureModelStorage<User> {
  SecureUserStorage({required super.key});

  @override
  User fromJson(Map<String, dynamic> json) {
    return User.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(User instance) {
    return instance.toJson();
  }
}
