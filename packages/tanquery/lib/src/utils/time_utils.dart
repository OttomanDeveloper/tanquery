import 'dart:math' as math;

/// Calculates how much time remains before data becomes stale.
///
/// Returns [Duration.zero] if the data is already stale.
Duration timeUntilStale(DateTime updatedAt, Duration staleTime) {
  final elapsed = DateTime.now().difference(updatedAt);
  final remaining = staleTime - elapsed;
  return remaining.isNegative ? Duration.zero : remaining;
}

/// Returns true if [duration] is non-null and strictly positive.
bool isValidTimeout(Duration? duration) {
  if (duration == null) return false;
  if (duration.isNegative) return false;
  if (duration == Duration.zero) return false;
  return true;
}

/// Exponential backoff delay capped at 30 seconds.
///
/// Computes `1000 * 2^failureCount` milliseconds, so the sequence is
/// 2s, 4s, 8s, 16s, 30s, 30s, ...
Duration defaultRetryDelay(int failureCount) {
  return Duration(
    milliseconds: math.min(1000 * math.pow(2, failureCount).toInt(), 30000),
  );
}
