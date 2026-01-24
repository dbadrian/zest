import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

FlutterSecureStorage createSecureStorage({
  bool useEncryptedSharedPreferences = true,
}) {
  return FlutterSecureStorage(
    aOptions: AndroidOptions(
        encryptedSharedPreferences: useEncryptedSharedPreferences,
        sharedPreferencesName: "zest_secure_storage",
        preferencesKeyPrefix: 'zest_'),
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    mOptions: const MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    lOptions: const LinuxOptions(),
    wOptions: const WindowsOptions(),
  );
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return createSecureStorage(
    useEncryptedSharedPreferences: true,
  );
});

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

abstract class SecureModelStorage<T> extends ModelStorage<T> {
  final String key;
  final FlutterSecureStorage _storage;

  SecureModelStorage({
    required this.key,
    required FlutterSecureStorage storage,
  }) : _storage = storage;

  @override
  Future<T?> read() async {
    final jsonStr = await _storage.read(key: key);
    if (jsonStr != null) {
      try {
        return fromJson(jsonDecode(jsonStr));
      } catch (e) {
        debugPrint("Failure decoding key (invalid Json): $key: $e -- $jsonStr");
        await clear();
        return null;
      }
    } else {
      return null;
    }
  }

  @override
  Future<void> save(T instance) async {
    await _storage.write(key: key, value: jsonEncode(toJson(instance)));
  }

  @override
  Future<void> clear() async {
    debugPrint("Clearing $key from secure storage");
    final hasKey = await _storage.containsKey(key: key);
    if (hasKey) await _storage.delete(key: key);
  }

  T fromJson(Map<String, dynamic> json);

  Map<String, dynamic> toJson(T instance);
}
