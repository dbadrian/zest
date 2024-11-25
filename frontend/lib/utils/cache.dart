import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'cache.g.dart';

class CacheWithExpiration {
  final String keyIdPrefix = "S&23as8d78132-382781-37742";
  final String keyDatePostfix = "@&#*87238ys8s27@*(#)";

  // Function to save data with an expiration date to SharedPreferences
  String _constructPrimayKey(String key) {
    return "${keyIdPrefix}_$key";
  }

  String _constructDateKey(String key) {
    return "${keyIdPrefix}_${key}_date_$keyDatePostfix";
  }

  Future<bool> save(String key, String data) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      DateTime recordTime = DateTime.now();
      await prefs.setString(_constructPrimayKey(key), data);
      await prefs.setString(
          _constructDateKey(key), recordTime.toIso8601String());
      debugPrint('Data saved to SharedPreferences.');
      return true;
    } catch (e) {
      debugPrint('Error saving data to SharedPreferences: $e');
      return false;
    }
  }

  // Function to get data from SharedPreferences if it's not expired
  Future<String?> getDataIfNotExpired(
      String key, Duration expirationDuration) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? data = prefs.getString(_constructPrimayKey(key));
      final dateKey = _constructDateKey(key);
      String? expirationTimeStr = prefs.getString(dateKey);
      if (data == null || expirationTimeStr == null) {
        debugPrint('No data or expiration time found in SharedPreferences.');
        return null; // No data or expiration time found.
      }

      DateTime expirationTime = DateTime.parse(expirationTimeStr);
      if (expirationTime.add(expirationDuration).isAfter(DateTime.now())) {
        debugPrint('Data has not expired.');
        // The data has not expired.
        return data;
      } else {
        // Data has expired. Remove it from SharedPreferences.
        await prefs.remove(_constructPrimayKey(key));
        await prefs.remove(dateKey);
        debugPrint('Data has expired. Removed from SharedPreferences.');
        return null;
      }
    } catch (e) {
      debugPrint('Error retrieving data from SharedPreferences: $e');
      return null;
    }
  }

  // Function to clear data from SharedPreferences
  Future<void> clearKey(String key) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_constructPrimayKey(key));
      await prefs.remove(_constructDateKey(key));
      debugPrint('Data cleared from SharedPreferences.');
    } catch (e) {
      debugPrint('Error clearing data from SharedPreferences: $e');
    }
  }

  Future<void> clearAll(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    final keys = prefs.getKeys();
    final filteredKeys =
        keys.where((element) => element.startsWith(keyIdPrefix));
    for (final k in filteredKeys) {
      clearKey(k);
    }
  }
}

@Riverpod(keepAlive: true)
CacheWithExpiration cacheWithExpiration(CacheWithExpirationRef ref) =>
    CacheWithExpiration();
