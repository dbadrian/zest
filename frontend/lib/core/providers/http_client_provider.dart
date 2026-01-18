import 'package:flutter/rendering.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/authentication/auth_interceptor.dart';
import 'package:zest/authentication/auth_service.dart';
import 'package:zest/settings/settings_provider.dart';
import '../network/http_client.dart';
import '../network/interceptors/logging_interceptor.dart';

part 'http_client_provider.g.dart';

@Riverpod(keepAlive: false)
ApiHttpClient apiClient(Ref ref, {required bool withAuthentication}) {
  debugPrint('🟢 apiClient CREATED: $withAuthentication with Auth?');
  final String apiBaseUrl =
      ref.watch(settingsProvider.select((p) => p.current.apiUrl));

  final client = ApiHttpClient(baseUrl: apiBaseUrl);

  if (withAuthentication) {
    client.addInterceptor(
      AuthInterceptor(
        getAccessToken: () async {
          final authState = ref.read(authenticationServiceProvider);
          return authState.valueOrNull?.accessToken;
        },
        refreshToken: () async {
          await ref.read(authenticationServiceProvider.notifier).refreshToken();
        },
        onUnauthorized: () async {
          debugPrint("onUnauthorized got called from AuthInterceptor");
          await ref.read(authenticationServiceProvider.notifier).logout();
        },
      ),
    );
  }

  // Add logging in debug mode
  client.addInterceptor(
    LoggingInterceptor(
      enabled: const bool.fromEnvironment('dart.vm.product') == false,
    ),
  );

  ref.onDispose(() {
    debugPrint('🔴 apiClient value DISPOSED');
    client.dispose();
  });

  return client;
}
