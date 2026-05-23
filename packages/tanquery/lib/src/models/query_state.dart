import 'types.dart';

/// Immutable snapshot of a query's current state.
///
/// Holds the fetched [data], any [error], status flags, and metadata
/// about when data and errors were last updated.
class QueryState<TData> {
  /// The data returned by the query function, or null if not yet fetched.
  final TData? data;

  /// The error from the last failed fetch, or null on success.
  final Object? error;

  /// Overall data status (pending, success, or error).
  final QueryStatus status;

  /// Current network activity status (fetching, paused, or idle).
  final FetchStatus fetchStatus;

  /// Whether this query has been explicitly invalidated.
  final bool isInvalidated;

  /// When [data] was last successfully updated.
  final DateTime? dataUpdatedAt;

  /// When [error] was last set.
  final DateTime? errorUpdatedAt;

  /// Number of consecutive fetch failures.
  final int fetchFailureCount;

  /// The error that caused the most recent fetch failure.
  final Object? fetchFailureReason;

  /// Total number of times data has been updated.
  final int dataUpdateCount;

  /// Total number of times an error has been recorded.
  final int errorUpdateCount;

  /// Arbitrary metadata attached to the fetch request.
  final Map<String, Object?>? fetchMeta;

  /// Creates a query state with the given values.
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

  /// True when data has never been fetched and a fetch is in progress.
  bool get isLoading =>
      status == QueryStatus.pending && fetchStatus == FetchStatus.fetching;

  /// True when any fetch is in progress, including background refetches.
  bool get isFetching => fetchStatus == FetchStatus.fetching;

  /// True when the fetch is paused waiting for network.
  bool get isPaused => fetchStatus == FetchStatus.paused;

  /// True when the last fetch resulted in an error.
  bool get isError => status == QueryStatus.error;

  /// True when data has been fetched successfully.
  bool get isSuccess => status == QueryStatus.success;

  /// True when no data has been fetched yet.
  bool get isPending => status == QueryStatus.pending;

  /// Whether [data] is non-null.
  bool get hasData => data != null;

  /// Whether [error] is non-null.
  bool get hasError => error != null;

  /// Returns a copy with the specified fields replaced.
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
