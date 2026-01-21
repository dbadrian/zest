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

// Map<String, dynamic> mergeMaps(
//     Map<String, dynamic> map1, Map<dynamic, dynamic> map2) {
//   Map<String, dynamic> result = Map.from(map1); // Start with map1
//   map2.forEach((key, value) {
//     if (result.containsKey(key) && result[key] is Map) {
//       if (value is Map) {
//       result[key] = mergeMaps(result[key], value); // Recurse for nested maps

//       } else if (value is List<Map> && result[key] is Map) {
//         // both elements are maps so we can do an inner merge
//           // this assumes everything inside a map...
//           result[key] = value.asMap().map((idx, value) => {idx, mergeMaps(result[key][idx], value)});

//         }
//       }
//     } else {
//       result[key] = value; // Overwrite or add new
//     }
//   });
//   return result;
// }

Map<String, dynamic> mergeMaps(
    Map<String, dynamic> map1, Map<dynamic, dynamic> map2) {
  final result = Map<String, dynamic>.from(map1);

  map2.forEach((key, value) {
    if (result.containsKey(key)) {
      final existing = result[key];

      // If both values are maps → merge recursively
      if (existing is Map && value is Map) {
        result[key] = mergeMaps(
          Map<String, dynamic>.from(existing),
          value,
        );
      }

      // If both values are List<Map> → merge element-wise
      else if (existing is List && value is List) {
        if (existing.isNotEmpty &&
            value.isNotEmpty &&
            existing.first is Map &&
            value.first is Map) {
          // merge element-by-element
          final mergedList = <Map<String, dynamic>>[];
          final maxLen =
              existing.length > value.length ? existing.length : value.length;

          for (var i = 0; i < maxLen; i++) {
            if (i < existing.length && i < value.length) {
              mergedList.add(
                mergeMaps(
                  Map<String, dynamic>.from(existing[i]),
                  Map<String, dynamic>.from(value[i]),
                ),
              );
            } else if (i < existing.length) {
              mergedList.add(Map<String, dynamic>.from(existing[i]));
            } else {
              mergedList.add(Map<String, dynamic>.from(value[i]));
            }
          }

          result[key] = mergedList;
        } else {
          // fallback → overwrite list
          result[key] = value;
        }
      }

      // Otherwise → overwrite with new value
      else {
        result[key] = value;
      }
    } else {
      // New key → insert it
      result[key] = value;
    }
  });

  return result;
}
