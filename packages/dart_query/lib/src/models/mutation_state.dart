import 'types.dart';

class MutationState<TData> {
  final TData? data;
  final Object? error;
  final MutationStatus status;
  final int failureCount;
  final Object? failureReason;
  final bool isPaused;
  final Object? variables;
  final Object? context;
  final DateTime? submittedAt;

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

  bool get isIdle => status == MutationStatus.idle;
  bool get isPending => status == MutationStatus.pending;
  bool get isError => status == MutationStatus.error;
  bool get isSuccess => status == MutationStatus.success;

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
