import 'types.dart';

/// Immutable snapshot of a mutation's current state.
///
/// Tracks the [data] returned on success, any [error], retry counts,
/// and the [variables] that were passed to the mutation function.
final class MutationState<TData> {
  /// The data returned by the mutation function, or null if not yet completed.
  final TData? data;

  /// The error from the last failed mutation attempt, or null on success.
  final Object? error;

  /// Current mutation status.
  final MutationStatus status;

  /// Number of consecutive failures.
  final int failureCount;

  /// The error that caused the most recent failure.
  final Object? failureReason;

  /// Whether the mutation is paused waiting for network.
  final bool isPaused;

  /// The input variables passed to the mutation function.
  final Object? variables;

  /// User-defined context passed through mutation lifecycle callbacks.
  final Object? context;

  /// When the mutation was submitted.
  final DateTime? submittedAt;

  /// Creates a mutation state with the given values.
  const MutationState({
    this.data,
    this.error,
    this.status = MutationStatus.idle,
    this.failureCount = 0,
    this.failureReason,
    this.isPaused = false,
    this.variables,
    this.context,
    this.submittedAt,
  });

  /// True when the mutation has not been triggered.
  bool get isIdle => status == MutationStatus.idle;

  /// True when the mutation is running.
  bool get isPending => status == MutationStatus.pending;

  /// True when the mutation failed.
  bool get isError => status == MutationStatus.error;

  /// True when the mutation completed successfully.
  bool get isSuccess => status == MutationStatus.success;

  /// Returns a copy with the specified fields replaced.
  MutationState<TData> copyWith({
    TData? Function()? data,
    Object? Function()? error,
    MutationStatus? status,
    int? failureCount,
    Object? Function()? failureReason,
    bool? isPaused,
    Object? Function()? variables,
    Object? Function()? context,
    DateTime? Function()? submittedAt,
  }) {
    return MutationState<TData>(
      data: data != null ? data() : this.data,
      error: error != null ? error() : this.error,
      status: status ?? this.status,
      failureCount: failureCount ?? this.failureCount,
      failureReason:
          failureReason != null ? failureReason() : this.failureReason,
      isPaused: isPaused ?? this.isPaused,
      variables: variables != null ? variables() : this.variables,
      context: context != null ? context() : this.context,
      submittedAt: submittedAt != null ? submittedAt() : this.submittedAt,
    );
  }
}
