import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_status_provider.g.dart'; // Generated file

@riverpod
class ApiStatus extends _$ApiStatus {
  Timer? _timer;

  @override
  Future<({bool isOnline, bool redirects})> build() async {
    startChecking(const Duration(seconds: 5));
    return await _checkBackendStatus();
  }

  Future<({bool isOnline, bool redirects})> _checkBackendStatus() async {
    // final SettingsState settings = ref.read(settingsProvider);

    return (isOnline: true, redirects: false);
    // try {
    //   final response =
    //       await http.get(getAPIUrl(settings, "/info", withPostSlash: false));
    //   // return response.statusCode == 200; // Online if status is 200
    //   final isOnline = response.statusCode == 200 || response.statusCode == 201;
    //   var redirects = false;
    //   if (isOnline) {
    //     final response2 =
    //         await http.post(getAPIUrl(settings, "/info", withPostSlash: false));
    //     if ((response2.statusCode == 301 || response2.statusCode == 302) &&
    //         response2.headers['location']?.startsWith('https://') == true) {
    //       redirects = true; // Redirects to HTTPS
    //     }
    //   }
    //   debugPrint("isOnline: $isOnline, redirects: $redirects");
    //   return (isOnline: isOnline, redirects: redirects);
    // } catch (_) {
    //   return (isOnline: false, redirects: false); // Offline in case of errors
    // }
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
    state = AsyncValue.data(
        (isOnline: isOnline, redirects: state.valueOrNull?.redirects ?? false));
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
