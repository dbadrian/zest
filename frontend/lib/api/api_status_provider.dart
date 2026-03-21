import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/core/network/api_response.dart';
import 'package:zest/core/providers/http_client_provider.dart';

part 'api_status_provider.g.dart'; // Generated file

@riverpod
class ApiStatus extends _$ApiStatus {
  Timer? _timer;

  @override
  Future<({bool isOnline})> build() async {
    ref.watch(apiClientProvider(withAuthentication: false));

    ref.onDispose(() {
      _timer?.cancel();
    });

    startChecking(const Duration(seconds: kDebugMode ? 10 : 2));
    return await _checkBackendStatus();
  }

  Future<({bool isOnline})> _checkBackendStatus() async {
    // final SettingsState settings = ref.read(settingsProvider);
    final client = ref.watch(apiClientProvider(withAuthentication: false));

    try {
      final response = await AsyncValue.guard(
          () => client.get<Map<String, dynamic>>("/info", (e) => e));

      if (!ref.mounted) return (isOnline: false);

      if (response.hasValue) {
        if (response.value is ApiSuccess) {
          return (isOnline: true);
        } else {
          return (isOnline: false);
        }
      } else {
        return (isOnline: false);
      }
    } catch (_) {
      return (isOnline: false); // Offline in case of errors
    }
  }

  // Start periodic checks
  void startChecking(Duration interval) {
    _timer?.cancel(); // Cancel existing timer
    _timer = Timer.periodic(interval, (_) async {
      state = await AsyncValue.guard(() => _checkBackendStatus());
    });
    // Immediately update state
    _updateStatus();
  }

  // Update the status once without waiting for the periodic interval
  Future<void> _updateStatus() async {
    final result = await AsyncValue.guard(() => _checkBackendStatus());

    if (!ref.mounted) return; // ⚡ important!

    state = result;
  }

  Future<void> forceUpdateStatus(bool isOnline) async {
    final result = AsyncValue.data((isOnline: isOnline));

    if (!ref.mounted) return; // ⚡ important!

    state = result;
  }
}
