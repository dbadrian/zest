import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ModelStorage<T> {
  // Abstract class defining storage instance of some class T

  // Read token to storage
  Future<T?> read();

  // Save token to storage
  Future<void> save(T instance);

  // Clear token from storage
  Future<void> clear();
}

class InMemoryModelStorage<T> extends ModelStorage<T> {
  T? _instance;

  @override
  Future<T?> read() async {
    return _instance;
  }

  @override
  Future<void> save(T instance) async {
    _instance = instance;
  }

  @override
  Future<void> clear() async {
    _instance = null;
  }
}

// abstract class SharedPreferenacesModelStorage<T> extends ModelStorage<T> {
//   final String key;
//   final SharedPreferences storage;

//   SharedPreferenacesModelStorage({required this.key, required this.storage});

//   @override
//   Future<T?> read() async {
//     final jsonStr = storage.getString(key);
//     if (jsonStr != null) {
//       return fromJson(jsonDecode(jsonStr));
//     } else {
//       return null;
//     }
//   }

//   @override
//   Future<void> save(T instance) async {
//     await storage.setString(key, jsonEncode(toJson(instance)));
//   }

//   @override
//   Future<void> clear() async {
//     final hasKey = await storage.containsKey(key);
//     if (hasKey) await storage.remove(key);
//   }

//   T fromJson(Map<String, dynamic> json);

//   Map<String, dynamic> toJson(T instance);
// }

abstract class SecureModelStorage<T> extends ModelStorage<T> {
  final String key;
  late final FlutterSecureStorage _storage;

  SecureModelStorage({required this.key}) {
    // if we are on android
    if (Platform.isAndroid) {
      _storage = FlutterSecureStorage(aOptions: _getAndroidOptions());
    } else {
      _storage = const FlutterSecureStorage();
    }
  }

  /// Android options for secure storage
  /// https://github.com/mogol/flutter_secure_storage/issues/487#issuecomment-1346244368
  AndroidOptions _getAndroidOptions() => const AndroidOptions(
        encryptedSharedPreferences: true,
      );

  @override
  Future<T?> read() async {
    final jsonStr =
        await _storage.read(key: key, aOptions: _getAndroidOptions());
    if (jsonStr != null) {
      try {
        return fromJson(jsonDecode(jsonStr));
      } catch (e) {
        debugPrint("Failure decoding key (invalid Json): $key: $e -- $jsonStr");
        return null;
      }
    } else {
      return null;
    }
  }

  @override
  Future<void> save(T instance) async {
    await _storage.write(
        key: key,
        value: jsonEncode(toJson(instance)),
        aOptions: _getAndroidOptions());
  }

  @override
  Future<void> clear() async {
    debugPrint("Clearing $key from secure storage");
    final hasKey =
        await _storage.containsKey(key: key, aOptions: _getAndroidOptions());
    if (hasKey) await _storage.delete(key: key, aOptions: _getAndroidOptions());
  }

  T fromJson(Map<String, dynamic> json);

  Map<String, dynamic> toJson(T instance);
}
