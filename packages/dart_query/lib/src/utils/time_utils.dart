import 'dart:math' as math;

Duration timeUntilStale(DateTime updatedAt, Duration staleTime) {
  final elapsed = DateTime.now().difference(updatedAt);
  final remaining = staleTime - elapsed;
  return remaining.isNegative ? Duration.zero : remaining;
}

bool isValidTimeout(Duration? duration) {
  if (duration == null) return false;
  if (duration.isNegative) return false;
  if (duration == Duration.zero) return false;
  return true;
}

Duration defaultRetryDelay(int failureCount) {
  return Duration(
    milliseconds: math.min(1000 * math.pow(2, failureCount).toInt(), 30000),
  );
}
