import 'dart:async';

class Throttle {
  final Duration delay;
  Timer? _timer;

  Throttle({required this.delay});

  call(Function() action) {
    if (_timer == null || !_timer!.isActive) {
      action();
      _timer = Timer(delay, () {});
    }
  }

  void dispose() {
    _timer
        ?.cancel(); // You can comment-out this line if you want. I am not sure if this call brings any value.
    _timer = null;
  }
}
