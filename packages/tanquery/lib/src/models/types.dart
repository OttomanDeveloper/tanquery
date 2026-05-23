/// The overall status of a query's data.
enum QueryStatus {
  /// No data has been fetched yet.
  pending,

  /// Data was fetched successfully.
  success,

  /// The last fetch resulted in an error.
  error,
}

/// The current network activity status of a query.
enum FetchStatus {
  /// A fetch is in progress.
  fetching,

  /// The fetch is paused (e.g. waiting for network).
  paused,

  /// No fetch is happening.
  idle,
}

/// The status of a mutation.
enum MutationStatus {
  /// The mutation has not been triggered.
  idle,

  /// The mutation is running.
  pending,

  /// The mutation completed successfully.
  success,

  /// The mutation failed.
  error,
}

/// Controls when queries are allowed to fetch.
enum NetworkMode {
  /// Only fetch when the device is online.
  online,

  /// Always fetch regardless of network state.
  always,

  /// Try the cache first, then fetch if needed.
  offlineFirst,
}

/// Controls how pages are refetched in infinite queries.
enum RefetchMode {
  /// Discard existing pages and start over.
  reset,

  /// Add new pages to existing ones.
  append,

  /// Replace existing pages with fresh data.
  replace,
}

/// Internal action types dispatched during the query lifecycle.
enum QueryActionType {
  /// A fetch was initiated.
  fetch,

  /// The fetch succeeded.
  success,

  /// The fetch failed.
  error,

  /// The query was invalidated.
  invalidate,

  /// The fetch was paused.
  pause,

  /// The fetch was resumed.
  resume,

  /// The fetch failed but may retry.
  failed,

  /// The state was set directly.
  setState,
}

/// Internal action types dispatched during the mutation lifecycle.
enum MutationActionType {
  /// The mutation started.
  pending,

  /// The mutation succeeded.
  success,

  /// The mutation failed.
  error,

  /// The mutation failed but may retry.
  failed,

  /// The mutation was paused.
  pause,

  /// The mutation was resumed.
  resume,
}

/// Events emitted by the query cache when entries change.
enum EventType {
  /// A new query or mutation was added to the cache.
  added,

  /// A query or mutation was removed from the cache.
  removed,

  /// A query or mutation's state was updated.
  updated,

  /// An observer started watching a query.
  observerAdded,

  /// An observer stopped watching a query.
  observerRemoved,
}

/// Filter for selecting queries by observer status.
enum QueryTypeFilter {
  /// Match all queries.
  all,

  /// Match only queries with active observers.
  active,

  /// Match only queries with no observers.
  inactive,
}

/// How long before cached data is considered stale.
///
/// Wrap a [Duration] for normal staleness, or use [StaleTime.static_]
/// to mark data as never stale.
class StaleTime {
  /// The staleness duration, or null if data never goes stale.
  final Duration? duration;

  /// Whether this represents a static (never-stale) staleness.
  final bool isStatic;

  const StaleTime._(this.duration, this.isStatic);

  /// Creates a stale time with the given [duration].
  factory StaleTime(Duration duration) => StaleTime._(duration, false);

  /// Data marked with this value is never considered stale.
  static const StaleTime static_ = StaleTime._(null, true);
}
