import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

Iterable<E> mapIndexed<E, T>(
    Iterable<T> items, E Function(int index, T item) f) sync* {
  var index = 0;

  for (final item in items) {
    yield f(index, item);
    index = index + 1;
  }
}

@immutable
class Pair<E, T> {
  final E left;
  final T right;

  const Pair(this.left, this.right);

  @override
  String toString() => 'Pair[$left, $right]';
}

bool isDesktop() {
  return !kIsWeb &&
      (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
}

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  bool run(VoidCallback action) {
    final ret = _timer?.isActive ?? false;
    if (ret) {
      _timer?.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
    return ret;
  }

  void dispose() {
    _timer?.cancel();
  }
}
