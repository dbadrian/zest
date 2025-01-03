import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/api/api_utils.dart';
import 'package:zest/settings/settings_provider.dart';

part 'api_status_provider.g.dart'; // Generated file

@riverpod
class ApiStatus extends _$ApiStatus {
  Timer? _timer;

  @override
  Future<bool> build() async {
    startChecking(const Duration(seconds: 5));
    return await _checkBackendStatus();
  }

  Future<bool> _checkBackendStatus() async {
    final SettingsState settings = ref.read(settingsProvider);

    try {
      final response =
          await http.get(getAPIUrl(settings, "/info", withPostSlash: false));
      return response.statusCode == 200; // Online if status is 200
    } catch (_) {
      return false; // Offline in case of errors
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
    state = await AsyncValue.guard(() => _checkBackendStatus());
  }

  Future<void> updateStatus(bool isOnline) async {
    state = AsyncValue.data(isOnline);
  }
}

// @riverpod
// class ApiStatus extends AsyncNotifier<bool> {
//   Timer? _timer;

//   @override
//   Future<bool> build() async {
//     // Initial state when the provider is first created
//     return _checkBackendStatus();
//   }

//   // Function to check backend status
//   Future<bool> _checkBackendStatus() async {
//     try {
//       final response =
//           await http.get(Uri.parse('https://dbadrian/api/v1/info'));
//       return response.statusCode == 200; // Online if status is 200
//     } catch (_) {
//       return false; // Offline in case of errors
//     }
//   }

//   // Start periodic checks
//   void startChecking(Duration interval) {
//     _timer?.cancel(); // Cancel existing timer
//     _timer = Timer.periodic(interval, (_) async {
//       state = await AsyncValue.guard(() => _checkBackendStatus());
//     });
//     // Immediately update state
//     _updateStatus();
//   }

//   // Update the status once without waiting for the periodic interval
//   Future<void> _updateStatus() async {
//     state = await AsyncValue.guard(() => _checkBackendStatus());
//   }

//   // Stop periodic checks
//   void stopChecking() {
//     _timer?.cancel();
//     _timer = null;
//   }

//   // @override
//   // void dispose() {
//   //   stopChecking();
//   //   super.dispose();
//   // }
// }
