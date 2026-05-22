import 'types.dart';

class QueryState<TData> {
  final TData? data;
  final Object? error;
  final QueryStatus status;
  final FetchStatus fetchStatus;
  final bool isInvalidated;
  final DateTime? dataUpdatedAt;
  final DateTime? errorUpdatedAt;
  final int fetchFailureCount;
  final Object? fetchFailureReason;
  final int dataUpdateCount;
  final int errorUpdateCount;
  final Map<String, Object?>? fetchMeta;

  const QueryState({
    this.data,
    this.error,
    this.status = QueryStatus.pending,
    this.fetchStatus = FetchStatus.idle,
    this.isInvalidated = false,
    this.dataUpdatedAt,
    this.errorUpdatedAt,
    this.fetchFailureCount = 0,
    this.fetchFailureReason,
    this.dataUpdateCount = 0,
    this.errorUpdateCount = 0,
    this.fetchMeta,
  });

  bool get isLoading =>
      status == QueryStatus.pending && fetchStatus == FetchStatus.fetching;
  bool get isFetching => fetchStatus == FetchStatus.fetching;
  bool get isPaused => fetchStatus == FetchStatus.paused;
  bool get isError => status == QueryStatus.error;
  bool get isSuccess => status == QueryStatus.success;
  bool get isPending => status == QueryStatus.pending;
  bool get hasData => data != null;
  bool get hasError => error != null;

  QueryState<TData> copyWith({
    TData? Function()? data,
    Object? Function()? error,
    QueryStatus? status,
    FetchStatus? fetchStatus,
    bool? isInvalidated,
    DateTime? Function()? dataUpdatedAt,
    DateTime? Function()? errorUpdatedAt,
    int? fetchFailureCount,
    Object? Function()? fetchFailureReason,
    int? dataUpdateCount,
    int? errorUpdateCount,
    Map<String, Object?>? Function()? fetchMeta,
  }) {
    return QueryState<TData>(
      data: data != null ? data() : this.data,
      error: error != null ? error() : this.error,
      status: status ?? this.status,
      fetchStatus: fetchStatus ?? this.fetchStatus,
      isInvalidated: isInvalidated ?? this.isInvalidated,
      dataUpdatedAt:
          dataUpdatedAt != null ? dataUpdatedAt() : this.dataUpdatedAt,
      errorUpdatedAt:
          errorUpdatedAt != null ? errorUpdatedAt() : this.errorUpdatedAt,
      fetchFailureCount: fetchFailureCount ?? this.fetchFailureCount,
      fetchFailureReason:
          fetchFailureReason != null ? fetchFailureReason() : this.fetchFailureReason,
      dataUpdateCount: dataUpdateCount ?? this.dataUpdateCount,
      errorUpdateCount: errorUpdateCount ?? this.errorUpdateCount,
      fetchMeta: fetchMeta != null ? fetchMeta() : this.fetchMeta,
    );
  }
}
