import 'core/focus_manager.dart';
import 'core/notify_manager.dart' as nm;
import 'core/online_manager.dart';
import 'core/subscribable.dart';
import 'models/query_key.dart';
import 'models/query_state.dart';
import 'models/types.dart';
import 'mutation/mutation_cache.dart';
import 'query/query.dart';
import 'query/query_cache.dart';

/// The main entry point for interacting with tanquery.
///
/// Owns a [QueryCache] and [MutationCache]. Provides methods to read cached
/// data, trigger fetches, invalidate queries, and control mutations. Typically
/// created once at app startup and passed to a provider widget.
class QueryClient {
  final QueryCache _queryCache;
  final MutationCache _mutationCache;
  final nm.NotifyManager _notifyManager;
  final FocusManager _focusManager;
  final OnlineManager _onlineManager;

  int _mountCount = 0;
  Unsubscribe? _unsubscribeFocus;
  Unsubscribe? _unsubscribeOnline;

  /// How long fetched data is considered fresh before becoming stale.
  Duration defaultStaleTime;

  /// How long unused queries remain in the cache after their last observer
  /// unsubscribes. Defaults to 5 minutes.
  Duration defaultGcTime;

  /// Default number of retries for failed query fetches.
  int defaultRetryCount;

  /// Default network mode for queries.
  NetworkMode defaultNetworkMode;

  /// Default number of retries for failed mutations.
  int defaultMutationRetryCount;

  /// Creates a new client with optional custom caches and defaults.
  ///
  /// If [queryCache] or [mutationCache] are not provided, new instances
  /// are created internally. The default options apply to all queries and
  /// mutations unless overridden per-call.
  QueryClient({
    QueryCache? queryCache,
    MutationCache? mutationCache,
    nm.NotifyManager? notifyManager,
    FocusManager? focusManager,
    OnlineManager? onlineManager,
    this.defaultStaleTime = Duration.zero,
    this.defaultGcTime = const Duration(minutes: 5),
    this.defaultRetryCount = 3,
    this.defaultNetworkMode = NetworkMode.online,
    this.defaultMutationRetryCount = 0,
  })  : _queryCache = queryCache ?? QueryCache(
          notifyManager: notifyManager,
          focusManager: focusManager,
          onlineManager: onlineManager,
        ),
        _mutationCache = mutationCache ?? MutationCache(
          notifyManager: notifyManager,
          focusManager: focusManager,
          onlineManager: onlineManager,
        ),
        _notifyManager = notifyManager ?? nm.notifyManager,
        _focusManager = focusManager ?? FocusManager.instance,
        _onlineManager = onlineManager ?? OnlineManager.instance;

  // --- Accessors ---

  /// Returns the underlying query cache.
  QueryCache getQueryCache() => _queryCache;

  /// Returns the underlying mutation cache.
  MutationCache getMutationCache() => _mutationCache;

  // --- Lifecycle ---

  /// Activates the client by subscribing to focus and online events.
  ///
  /// Reference-counted, so multiple mounts require the same number of
  /// [unmount] calls. The first mount sets up listeners that resume
  /// paused mutations and refetch stale queries on focus/reconnect.
  void mount() {
    _mountCount++;
    if (_mountCount != 1) return;

    _unsubscribeFocus = _focusManager.subscribe((focused) {
      if (focused) {
        _mutationCache.resumePausedMutations();
        _queryCache.onFocus();
      }
    });
    _unsubscribeOnline = _onlineManager.subscribe((online) {
      if (online) {
        _mutationCache.resumePausedMutations();
        _queryCache.onOnline();
      }
    });
  }

  /// Decrements the mount counter and tears down listeners when it hits zero.
  void unmount() {
    _mountCount--;
    if (_mountCount != 0) return;
    _unsubscribeFocus?.call();
    _unsubscribeFocus = null;
    _unsubscribeOnline?.call();
    _unsubscribeOnline = null;
  }

  // --- Query Data Access ---

  /// Returns the cached data for [queryKey], or null if not found.
  TData? getQueryData<TData>(QueryKey queryKey) {
    final hash = queryKey.queryHash;
    return _queryCache.get(hash)?.state.data as TData?;
  }

  /// Returns the full [QueryState] for [queryKey], or null if not cached.
  QueryState? getQueryState(QueryKey queryKey) {
    final hash = queryKey.queryHash;
    return _queryCache.get(hash)?.state;
  }

  /// Manually updates the cached data for [queryKey].
  ///
  /// The [updater] can be a raw value of type `TData`, a function
  /// `TData? Function(TData?)` that receives the previous data (or null),
  /// or a function `TData Function(TData)` when previous data is guaranteed
  /// to exist. Returns the new data value.
  TData setQueryData<TData>(QueryKey queryKey, Object updater, {DateTime? updatedAt}) {
    final query = _queryCache.build<TData>(
      queryKey: queryKey,
      gcTime: defaultGcTime,
    );
    final prevData = query.state.data;
    final TData data;
    if (updater is TData? Function(TData?)) {
      data = updater(prevData) as TData;
    } else if (updater is TData Function(TData) && prevData != null) {
      data = updater(prevData);
    } else {
      data = updater as TData;
    }
    return query.setData(data, updatedAt: updatedAt, manual: true);
  }

  // --- Query Operations ---

  /// Fetches data for [queryKey] and returns it.
  ///
  /// If cached data exists and is still fresh (per [staleTime]), returns it
  /// without making a network request. Does not retry on failure.
  Future<TData> fetchQuery<TData>({
    required QueryKey queryKey,
    required QueryFn<TData> queryFn,
    Duration? staleTime,
  }) async {
    final query = _queryCache.build<TData>(
      queryKey: queryKey,
      queryFn: queryFn,
      gcTime: defaultGcTime,
      retryCount: 0, // imperative fetches don't retry
      networkMode: defaultNetworkMode,
    );
    final effectiveStaleTime = staleTime ?? defaultStaleTime;
    if (query.isStaleByTime(effectiveStaleTime)) {
      return query.fetch();
    }
    return query.state.data as TData;
  }

  /// Like [fetchQuery], but swallows errors. Useful for warming the cache
  /// before navigating to a screen that needs the data.
  Future<void> prefetchQuery<TData>({
    required QueryKey queryKey,
    required QueryFn<TData> queryFn,
    Duration? staleTime,
  }) async {
    try {
      await fetchQuery<TData>(
        queryKey: queryKey,
        queryFn: queryFn,
        staleTime: staleTime,
      );
    } catch (_) {}
  }

  /// Returns cached data if available, otherwise fetches it.
  ///
  /// When [revalidateIfStale] is true and the existing data is stale,
  /// a background refetch is triggered (via [prefetchQuery]) while the
  /// stale data is returned immediately.
  Future<TData> ensureQueryData<TData>({
    required QueryKey queryKey,
    required QueryFn<TData> queryFn,
    Duration? staleTime,
    bool revalidateIfStale = false,
  }) async {
    final query = _queryCache.build<TData>(
      queryKey: queryKey,
      queryFn: queryFn,
      gcTime: defaultGcTime,
      retryCount: defaultRetryCount,
      networkMode: defaultNetworkMode,
    );

    if (query.state.data == null) {
      return fetchQuery<TData>(queryKey: queryKey, queryFn: queryFn, staleTime: staleTime);
    }

    final effectiveStaleTime = staleTime ?? defaultStaleTime;
    if (revalidateIfStale && query.isStaleByTime(effectiveStaleTime)) {
      prefetchQuery<TData>(queryKey: queryKey, queryFn: queryFn, staleTime: staleTime);
    }

    return query.state.data as TData;
  }

  // --- Query Control ---

  /// Marks matching queries as stale and optionally refetches active ones.
  ///
  /// Use [queryKey] with [exact] to target specific queries, or leave
  /// [queryKey] null to invalidate everything. The [refetchType] controls
  /// which queries are automatically refetched after invalidation.
  Future<void> invalidateQueries({
    QueryKey? queryKey,
    bool exact = false,
    QueryTypeFilter refetchType = QueryTypeFilter.active,
  }) async {
    _notifyManager.batch(() {
      for (final query in _queryCache.findAll(queryKey: queryKey, exact: exact)) {
        query.invalidate();
      }
    });

    await refetchQueries(queryKey: queryKey, exact: exact, type: refetchType);
  }

  /// Refetches matching queries that are not disabled.
  ///
  /// Paused queries are skipped. By default only active queries are
  /// refetched. Set [type] to [QueryTypeFilter.all] to include inactive ones.
  Future<void> refetchQueries({
    QueryKey? queryKey,
    bool exact = false,
    QueryTypeFilter type = QueryTypeFilter.active,
    bool cancelRefetch = true,
  }) async {
    final queries = _queryCache
        .findAll(queryKey: queryKey, exact: exact, type: type)
        .where((q) => !q.isDisabled());

    final futures = _notifyManager.batch(() {
      return queries.map((query) async {
        if (query.state.fetchStatus == FetchStatus.paused) return;
        try {
          await query.fetch(cancelRefetch: cancelRefetch);
        } catch (_) {}
      }).toList();
    });

    await Future.wait(futures);
  }

  /// Cancels in-flight fetches for matching queries.
  ///
  /// When [revert] is true (default), query state rolls back to before
  /// the cancelled fetch started.
  Future<void> cancelQueries({
    QueryKey? queryKey,
    bool exact = false,
    bool revert = true,
  }) async {
    final futures = _notifyManager.batch(() {
      return _queryCache
          .findAll(queryKey: queryKey, exact: exact)
          .map((query) => query.cancel(revert: revert))
          .toList();
    });
    await Future.wait(futures);
  }

  /// Removes matching queries from the cache entirely.
  void removeQueries({QueryKey? queryKey, bool exact = false}) {
    _notifyManager.batch(() {
      for (final query in _queryCache.findAll(queryKey: queryKey, exact: exact)) {
        _queryCache.remove(query);
      }
    });
  }

  /// Resets matching queries to their initial state, then refetches active ones.
  Future<void> resetQueries({QueryKey? queryKey, bool exact = false}) async {
    _notifyManager.batch(() {
      for (final query in _queryCache.findAll(queryKey: queryKey, exact: exact)) {
        query.reset();
      }
    });
    await refetchQueries(queryKey: queryKey, exact: exact, type: QueryTypeFilter.active);
  }

  // --- Mutation ---

  /// Resumes all paused mutations if the device is online.
  Future<void> resumePausedMutations() async {
    if (_onlineManager.isOnline()) {
      await _mutationCache.resumePausedMutations();
    }
  }

  // --- Counts ---

  /// Returns the number of queries currently fetching, optionally filtered
  /// by [queryKey].
  int isFetching({QueryKey? queryKey, bool exact = false}) {
    return _queryCache
        .findAll(queryKey: queryKey, exact: exact, fetchStatus: FetchStatus.fetching)
        .length;
  }

  /// Returns the number of mutations currently in a pending state.
  int isMutating() {
    return _mutationCache.findAll(status: MutationStatus.pending).length;
  }

  // --- Clear ---

  /// Removes all queries and mutations from both caches.
  void clear() {
    _queryCache.clear();
    _mutationCache.clear();
  }
}
