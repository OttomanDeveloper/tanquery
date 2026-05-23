/// Thrown when a query or mutation is cancelled before completing.
final class CancelledError extends Error {
  /// Whether the state should revert to the previous value.
  final bool revert;

  /// Whether the cancellation should be suppressed from error handlers.
  final bool silent;

  /// Creates a cancellation error.
  ///
  /// Set [revert] to true to roll back optimistic updates.
  /// Set [silent] to true to prevent error callbacks from firing.
  CancelledError({this.revert = false, this.silent = false});

  @override
  String toString() => 'CancelledError(revert: $revert, silent: $silent)';
}

/// Returns true if [error] is a [CancelledError].
bool isCancelledError(Object error) => error is CancelledError;
