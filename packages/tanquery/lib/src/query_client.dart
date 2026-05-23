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

class QueryClient {
  final QueryCache _queryCache;
  final MutationCache _mutationCache;
  final nm.NotifyManager _notifyManager;
  final FocusManager _focusManager;
  final OnlineManager _onlineManager;

  int _mountCount = 0;
  Unsubscribe? _unsubscribeFocus;
  Unsubscribe? _unsubscribeOnline;

  // Default options
  Duration defaultStaleTime;
  Duration defaultGcTime;
  int defaultRetryCount;
  NetworkMode defaultNetworkMode;
  int defaultMutationRetryCount;

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
  })  : _queryCache = queryCache ?? QueryCache(notifyManager: notifyManager),
        _mutationCache = mutationCache ?? MutationCache(
          notifyManager: notifyManager,
          focusManager: focusManager,
          onlineManager: onlineManager,
        ),
        _notifyManager = notifyManager ?? nm.notifyManager,
        _focusManager = focusManager ?? FocusManager.instance,
        _onlineManager = onlineManager ?? OnlineManager.instance;

  // --- Accessors ---

  QueryCache getQueryCache() => _queryCache;
  MutationCache getMutationCache() => _mutationCache;

  // --- Lifecycle ---

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

  void unmount() {
    _mountCount--;
    if (_mountCount != 0) return;
    _unsubscribeFocus?.call();
    _unsubscribeFocus = null;
    _unsubscribeOnline?.call();
    _unsubscribeOnline = null;
  }

  // --- Query Data Access ---

  TData? getQueryData<TData>(QueryKey queryKey) {
    final hash = queryKey.queryHash;
    return _queryCache.get(hash)?.state.data as TData?;
  }

  QueryState? getQueryState(QueryKey queryKey) {
    final hash = queryKey.queryHash;
    return _queryCache.get(hash)?.state;
  }

  TData setQueryData<TData>(QueryKey queryKey, Object updater, {DateTime? updatedAt}) {
    final query = _queryCache.build<TData>(
      queryKey: queryKey,
      gcTime: defaultGcTime,
    );
    final prevData = query.state.data;
    final TData data;
    if (updater is TData Function(TData)) {
      data = updater(prevData as TData);
    } else {
      data = updater as TData;
    }
    return query.setData(data, updatedAt: updatedAt, manual: true);
  }

  // --- Query Operations ---

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
      return queries.map((query) {
        if (query.state.fetchStatus == FetchStatus.paused) {
          return Future<void>.value();
        }
        return query.fetch(cancelRefetch: cancelRefetch).catchError((_) => null);
      }).toList();
    });

    await Future.wait(futures);
  }

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

  void removeQueries({QueryKey? queryKey, bool exact = false}) {
    _notifyManager.batch(() {
      for (final query in _queryCache.findAll(queryKey: queryKey, exact: exact)) {
        _queryCache.remove(query);
      }
    });
  }

  Future<void> resetQueries({QueryKey? queryKey, bool exact = false}) async {
    _notifyManager.batch(() {
      for (final query in _queryCache.findAll(queryKey: queryKey, exact: exact)) {
        query.reset();
      }
    });
    await refetchQueries(queryKey: queryKey, exact: exact, type: QueryTypeFilter.active);
  }

  // --- Mutation ---

  Future<void> resumePausedMutations() async {
    if (_onlineManager.isOnline()) {
      await _mutationCache.resumePausedMutations();
    }
  }

  // --- Counts ---

  int isFetching({QueryKey? queryKey, bool exact = false}) {
    return _queryCache
        .findAll(queryKey: queryKey, exact: exact, fetchStatus: FetchStatus.fetching)
        .length;
  }

  int isMutating() {
    return _mutationCache.findAll(status: MutationStatus.pending).length;
  }

  // --- Clear ---

  void clear() {
    _queryCache.clear();
    _mutationCache.clear();
  }
}
