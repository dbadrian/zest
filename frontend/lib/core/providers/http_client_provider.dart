import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/authentication/auth_interceptor.dart';
import 'package:zest/authentication/auth_service.dart';
import 'package:zest/settings/settings_provider.dart';
import '../network/http_client.dart';
import '../network/interceptors/logging_interceptor.dart';

part 'http_client_provider.g.dart';

@Riverpod(keepAlive: true)
ApiHttpClient apiClient(Ref ref) {
  // todo: read or watch?
  final String apiBaseUrl =
      ref.watch(settingsProvider.select((p) => p.current.apiUrl));

  final client = ApiHttpClient(baseUrl: apiBaseUrl);

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
        await ref.read(authenticationServiceProvider.notifier).logout();
      },
    ),
  );

  // Add logging in debug mode
  client.addInterceptor(
    LoggingInterceptor(
      enabled: const bool.fromEnvironment('dart.vm.product') == false,
    ),
  );

  ref.onDispose(() => client.dispose());

  return client;
}
