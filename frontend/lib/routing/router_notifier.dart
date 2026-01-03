// COPY FROM https://github.com/lucavenir/go_router_riverpod/blob/master/complete_example/lib/router_notifier.dart
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/authentication/auth_service.dart';

part 'router_notifier.g.dart';

@riverpod
class RouterAuthNotifier extends _$RouterAuthNotifier implements Listenable {
  VoidCallback? _listener;
  bool isAuthenticated = false;

  @override
  void build() {
    ref.listen(
      authenticationServiceProvider.select((value) => value),
      (_, next) {
        if (next.isLoading) return;
        // isAuthenticated = next.valueOrNull?.token != null;
        _listener?.call();
      },
    );
  }

  @override
  void addListener(VoidCallback listener) {
    _listener = listener;
  }

  @override
  void removeListener(VoidCallback listener) {
    _listener = null;
  }
}
