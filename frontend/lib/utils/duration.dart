String durationToHourMinuteString(Duration duration, {bool verbose = false}) {
  if (verbose) {
    return "${duration.inHours}h${duration.inMinutes.remainder(60)}m";
  } else {
    return "${duration.inHours}:${duration.inMinutes.remainder(60)}";
  }
}
