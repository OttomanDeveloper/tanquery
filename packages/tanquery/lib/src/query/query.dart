import 'dart:async';
import '../core/cancelled_error.dart';
import '../core/focus_manager.dart' as fm;
import '../core/notify_manager.dart' as nm;
import '../core/online_manager.dart' as om;
import '../core/removable.dart';
import '../models/query_key.dart';
import '../models/query_state.dart';
import '../models/types.dart';
import '../retryer/retryer.dart';
import '../utils/structural_sharing.dart';
import '../utils/skip_token.dart';

/// Async function that fetches data for a query.
typedef QueryFn<T> = Future<T> Function();

/// Interface for objects that want to observe a [Query]'s state changes.
///
/// Implemented by [QueryObserver] to receive notifications when a query's
/// state transitions (data arrival, errors, refetches).
abstract class QueryUpdateCallback {
  /// Called whenever the query's state changes.
  void onQueryUpdate();

  /// Whether this observer wants to trigger a refetch when the window regains focus.
  bool shouldFetchOnWindowFocus() => false;

  /// Whether this observer wants to trigger a refetch on network reconnect.
  bool shouldFetchOnReconnect() => false;

  /// Triggers a refetch of the observed query.
  Future<void> refetch({bool cancelRefetch});
}

/// Callback the [QueryCache] provides so the [Query] can emit lifecycle events
/// (added, removed, updated) back to cache-level listeners.
typedef CacheNotifyFn = void Function(Object event);

/// Manages a single query's lifecycle: fetching, caching, retrying, and
/// garbage collection.
///
/// Queries use a reducer-based state machine with two axes: [QueryStatus]
/// tracks whether data has arrived (pending/success/error) while [FetchStatus]
/// tracks the network request (fetching/paused/idle).
class Query<TData> extends Removable {
  /// The structured key that identifies this query.
  final QueryKey queryKey;

  /// Hash derived from [queryKey], used as the cache lookup key.
  final String queryHash;
  final nm.NotifyManager _notifyManager;
  final fm.FocusManager _focusManager;
  final om.OnlineManager _onlineManager;

  CacheNotifyFn? _cacheNotify;

  /// Current state of this query, including data, error, and status flags.
  QueryState<TData> state;
  QueryState<TData> _initialState;
  QueryState<TData>? _revertState;

  final List<QueryUpdateCallback> _observers = [];
  Retryer<TData>? _retryer;

  /// Called when the query is removed from the cache during garbage collection.
  void Function()? onRemove;

  /// The async function used to fetch data. Can be swapped via [setOptions].
  QueryFn<TData>? queryFn;

  /// Number of times to retry a failed fetch before giving up.
  int retryCount;

  /// Returns the delay before the [n]th retry attempt.
  Duration Function(int) retryDelay;

  /// Optional predicate that controls whether a given error should be retried.
  bool Function(Object)? retryCondition;

  /// Controls fetch behavior relative to network availability.
  NetworkMode networkMode;

  /// When true, new data is compared against existing data and references
  /// are preserved for unchanged portions. Reduces unnecessary rebuilds.
  bool structuralSharing;
  String? _queryType;

  /// Arbitrary metadata attached to this query, accessible from cache listeners.
  Map<String, Object?>? meta;

  /// Creates a query with the given [queryKey] and [queryHash].
  ///
  /// Optionally provide [initialData] to pre-populate the query's state
  /// without triggering a fetch. The [gcTime] controls how long the query
  /// stays in the cache after all observers unsubscribe.
  Query({
    required this.queryKey,
    required this.queryHash,
    Duration gcTime = const Duration(minutes: 5),
    TData? initialData,
    DateTime? initialDataUpdatedAt,
    this.queryFn,
    this.retryCount = 3,
    Duration Function(int)? retryDelay,
    this.retryCondition,
    this.networkMode = NetworkMode.online,
    this.structuralSharing = true,
    this.meta,
    String? queryType,
    QueryState<TData>? state,
    CacheNotifyFn? cacheNotify,
    nm.NotifyManager? notifyManager,
    fm.FocusManager? focusManager,
    om.OnlineManager? onlineManager,
  })  : _notifyManager = notifyManager ?? nm.notifyManager,
        _focusManager = focusManager ?? fm.focusManager,
        _onlineManager = onlineManager ?? om.onlineManager,
        _cacheNotify = cacheNotify,
        _queryType = queryType,
        retryDelay = retryDelay ?? _defaultRetryDelay,
        _initialState =
            state ?? _buildDefaultState(initialData, initialDataUpdatedAt),
        state = state ?? _buildDefaultState(initialData, initialDataUpdatedAt),
        super(gcTime: gcTime) {
    scheduleGc();
  }

  static Duration _defaultRetryDelay(int i) =>
      Duration(milliseconds: 1000 * (1 << i).clamp(1, 30));

  static QueryState<T> _buildDefaultState<T>(
      T? initialData, DateTime? initialDataUpdatedAt) {
    final hasData = initialData != null;
    return QueryState<T>(
      data: initialData,
      status: hasData ? QueryStatus.success : QueryStatus.pending,
      dataUpdatedAt: hasData ? (initialDataUpdatedAt ?? DateTime.now()) : null,
    );
  }

  // --- Getters ---

  /// Optional label grouping queries by type (e.g. "infinite", "paginated").
  String? get queryType => _queryType;

  // --- Options ---

  /// Updates query options in place. Only non-null parameters are applied.
  void setOptions({
    QueryFn<TData>? queryFn,
    int? retryCount,
    Duration Function(int)? retryDelay,
    bool Function(Object)? retryCondition,
    NetworkMode? networkMode,
    bool? structuralSharing,
    Duration? gcTime,
    Map<String, Object?>? meta,
    String? queryType,
  }) {
    if (queryFn != null) this.queryFn = queryFn;
    if (retryCount != null) this.retryCount = retryCount;
    if (retryDelay != null) this.retryDelay = retryDelay;
    if (retryCondition != null) this.retryCondition = retryCondition;
    if (networkMode != null) this.networkMode = networkMode;
    if (structuralSharing != null) this.structuralSharing = structuralSharing;
    if (gcTime != null) updateGcTime(gcTime);
    if (meta != null) this.meta = meta;
    if (queryType != null) _queryType = queryType;
  }

  // --- State Machine ---

  /// Stores [newData] in the query state and notifies observers.
  ///
  /// When [structuralSharing] is enabled, unchanged portions keep their
  /// original references. Set [manual] to true for programmatic updates
  /// (e.g. from [QueryClient.setQueryData]) that shouldn't clear fetch state.
  TData setData(TData newData, {DateTime? updatedAt, bool manual = false}) {
    final TData data;
    if (structuralSharing) {
      final shared = replaceEqualDeep(state.data, newData);
      data = (shared is TData) ? shared : newData;
    } else {
      data = newData;
    }
    _dispatch(_QueryAction.success(
        data: data, dataUpdatedAt: updatedAt, manual: manual));
    return data;
  }

  /// Replaces the entire query state. Use sparingly, prefer [setData].
  void setState(QueryState<TData> newState) {
    _dispatch(_QueryAction.setState(newState));
  }

  /// Marks this query as stale. Active observers will refetch on next check.
  void invalidate() {
    if (!state.isInvalidated) {
      _dispatch(_QueryAction.invalidate());
    }
  }

  void _dispatch(_QueryAction<TData> action) {
    state = _reducer(state, action);
    _notifyManager.batch(() {
      for (final observer in List.of(_observers)) {
        observer.onQueryUpdate();
      }
      _cacheNotify?.call({
        'query': this,
        'type': EventType.updated,
        'action': action.type,
      });
    });
  }

  QueryState<TData> _reducer(
      QueryState<TData> currentState, _QueryAction<TData> action) {
    switch (action.type) {
      case QueryActionType.fetch:
        final canFetchNow = networkMode == NetworkMode.online
            ? _onlineManager.isOnline()
            : true;
        return currentState.copyWith(
          fetchFailureCount: 0,
          fetchFailureReason: () => null,
          fetchStatus: canFetchNow ? FetchStatus.fetching : FetchStatus.paused,
          status: currentState.data == null ? QueryStatus.pending : null,
          error: currentState.data == null ? () => null : null,
          fetchMeta: () => action.meta,
        );
      case QueryActionType.success:
        var newState = currentState.copyWith(
          data: () => action.data,
          dataUpdatedAt: () => action.dataUpdatedAt ?? DateTime.now(),
          error: () => null,
          isInvalidated: false,
          status: QueryStatus.success,
          dataUpdateCount: currentState.dataUpdateCount + 1,
        );
        if (!action.manual) {
          newState = newState.copyWith(
            fetchStatus: FetchStatus.idle,
            fetchFailureCount: 0,
            fetchFailureReason: () => null,
          );
        }
        if (action.manual) {
          _revertState = newState;
        }
        return newState;
      case QueryActionType.error:
        return currentState.copyWith(
          error: () => action.error,
          errorUpdateCount: currentState.errorUpdateCount + 1,
          errorUpdatedAt: () => DateTime.now(),
          fetchFailureCount: currentState.fetchFailureCount + 1,
          fetchFailureReason: () => action.error,
          fetchStatus: FetchStatus.idle,
          status: QueryStatus.error,
        );
      case QueryActionType.invalidate:
        return currentState.copyWith(isInvalidated: true);
      case QueryActionType.pause:
        return currentState.copyWith(fetchStatus: FetchStatus.paused);
      case QueryActionType.resume:
        return currentState.copyWith(fetchStatus: FetchStatus.fetching);
      case QueryActionType.failed:
        return currentState.copyWith(
          fetchFailureCount:
              action.failureCount ?? currentState.fetchFailureCount,
          fetchFailureReason: () => action.error,
        );
      case QueryActionType.setState:
        return action.newState!;
    }
  }

  // --- Fetch ---

  /// Executes the [queryFn] and updates state through the reducer.
  ///
  /// If a fetch is already in-flight, [cancelRefetch] controls whether
  /// the existing request is cancelled (true) or reused (false).
  /// Returns the fetched data on success, throws on error.
  Future<TData> fetch({
    bool cancelRefetch = true,
    Map<String, Object?>? meta,
  }) async {
    if (state.fetchStatus != FetchStatus.idle && _retryer != null) {
      if (state.data != null && cancelRefetch) {
        _retryer!.cancel(silent: true);
      } else {
        _retryer!.continueRetry();
        return _retryer!.promise;
      }
    }

    _revertState = state;
    _dispatch(_QueryAction.fetch(meta: meta));

    _retryer = Retryer<TData>(
      fn: queryFn!,
      retryCount: retryCount,
      retryDelay: retryDelay,
      retryCondition: retryCondition,
      networkMode: networkMode,
      canRun: () => true,
      onFail: (count, error) =>
          _dispatch(_QueryAction.failed(failureCount: count, error: error)),
      onPause: () => _dispatch(_QueryAction.pause()),
      onContinue: () => _dispatch(_QueryAction.resume()),
      onCancel: (error) {
        if (error is CancelledError &&
            error.revert &&
            _revertState != null) {
          state = _revertState!.copyWith(fetchStatus: FetchStatus.idle);
        }
      },
      focusManager: _focusManager,
      onlineManager: _onlineManager,
    );

    try {
      final data = await _retryer!.start();
      setData(data);
      return data;
    } catch (error) {
      if (error is CancelledError) {
        if (error.silent) return _retryer!.promise;
        if (error.revert) {
          if (state.data != null) return state.data as TData;
          rethrow;
        }
      }
      _dispatch(_QueryAction.error(error: error));
      rethrow;
    } finally {
      scheduleGc();
    }
  }

  /// Cancels the in-flight fetch, if any.
  ///
  /// When [revert] is true, the state rolls back to before the fetch started.
  /// When [silent] is true, the cancellation does not trigger error handling.
  Future<void> cancel({bool revert = false, bool silent = false}) async {
    _retryer?.cancel(revert: revert, silent: silent);
    try {
      await _retryer?.promise;
    } catch (_) {}
  }

  @override
  void destroy() {
    super.destroy();
    _retryer?.cancel(silent: true);
  }

  /// Resets the query to its initial state, cancelling any in-flight fetch
  /// and restarting garbage collection.
  void reset() {
    destroy();
    _dispatch(_QueryAction.setState(_initialState));
    scheduleGc();
  }

  // --- Staleness ---

  /// Returns true if the query's data is stale relative to [staleTime].
  ///
  /// A query with no data is always stale. Invalidated queries are always
  /// stale regardless of [staleTime]. Accepts a [Duration] or [StaleTime].
  bool isStaleByTime(Object staleTime) {
    if (state.data == null) return true;
    if (staleTime is StaleTime && staleTime.isStatic) return false;
    if (state.isInvalidated) return true;
    if (state.dataUpdatedAt == null) return true;
    final duration =
        staleTime is StaleTime ? (staleTime.duration ?? Duration.zero) : staleTime as Duration;
    final elapsed = DateTime.now().difference(state.dataUpdatedAt!);
    return elapsed >= duration;
  }

  /// True when at least one observer is subscribed.
  bool isActive() => _observers.isNotEmpty;

  /// True when no observers are watching and either the query function is
  /// a skip token or no fetch has been attempted yet.
  bool isDisabled() {
    if (_observers.isNotEmpty) return false;
    return isSkipToken(queryFn) || !isFetched();
  }

  /// True if at least one fetch attempt has completed (success or error).
  bool isFetched() => state.dataUpdateCount + state.errorUpdateCount > 0;

  // --- Observers ---

  /// Registers an observer. Stops garbage collection while observers exist.
  void addObserver(QueryUpdateCallback observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
      clearGcTimeout();
      _cacheNotify?.call({
        'query': this,
        'type': EventType.observerAdded,
        'observer': observer,
      });
    }
  }

  /// Unregisters an observer. When the last observer is removed, retry is
  /// cancelled and garbage collection is scheduled.
  void removeObserver(QueryUpdateCallback observer) {
    if (!_observers.contains(observer)) return;
    _observers.remove(observer);
    if (_observers.isEmpty) {
      _retryer?.cancelRetry();
      scheduleGc();
    }
    _cacheNotify?.call({
      'query': this,
      'type': EventType.observerRemoved,
      'observer': observer,
    });
  }

  /// Number of observers currently subscribed to this query.
  int get observerCount => _observers.length;

  /// The initial state this query was created with, used by [reset].
  QueryState<TData> get resetState => _initialState;

  // --- Events ---

  /// Called when the app window regains focus. Triggers a refetch if any
  /// observer opts in via [QueryUpdateCallback.shouldFetchOnWindowFocus].
  void onFocus() {
    final observer = _observers
        .cast<QueryUpdateCallback?>()
        .firstWhere((o) => o!.shouldFetchOnWindowFocus(), orElse: () => null);
    observer?.refetch(cancelRefetch: false);
    _retryer?.resume();
  }

  /// Called when network connectivity is restored. Triggers a refetch if
  /// any observer opts in via [QueryUpdateCallback.shouldFetchOnReconnect].
  void onOnline() {
    final observer = _observers
        .cast<QueryUpdateCallback?>()
        .firstWhere((o) => o!.shouldFetchOnReconnect(), orElse: () => null);
    observer?.refetch(cancelRefetch: false);
    _retryer?.resume();
  }

  // --- GC ---

  @override
  void optionalRemove() {
    if (_observers.isEmpty && state.fetchStatus == FetchStatus.idle) {
      onRemove?.call();
    }
  }
}

class _QueryAction<T> {
  final QueryActionType type;
  final T? data;
  final Object? error;
  final DateTime? dataUpdatedAt;
  final bool manual;
  final int? failureCount;
  final QueryState<T>? newState;
  final Map<String, Object?>? meta;

  const _QueryAction._({
    required this.type,
    this.data,
    this.error,
    this.dataUpdatedAt,
    this.manual = false,
    this.failureCount,
    this.newState,
    this.meta,
  });

  factory _QueryAction.fetch({Map<String, Object?>? meta}) =>
      _QueryAction._(type: QueryActionType.fetch, meta: meta);
  factory _QueryAction.success(
          {required T data, DateTime? dataUpdatedAt, bool manual = false}) =>
      _QueryAction._(
          type: QueryActionType.success,
          data: data,
          dataUpdatedAt: dataUpdatedAt,
          manual: manual);
  factory _QueryAction.error({required Object error}) =>
      _QueryAction._(type: QueryActionType.error, error: error);
  factory _QueryAction.invalidate() =>
      _QueryAction._(type: QueryActionType.invalidate);
  factory _QueryAction.pause() =>
      _QueryAction._(type: QueryActionType.pause);
  factory _QueryAction.resume() =>
      _QueryAction._(type: QueryActionType.resume);
  factory _QueryAction.failed({int? failureCount, Object? error}) =>
      _QueryAction._(
          type: QueryActionType.failed,
          failureCount: failureCount,
          error: error);
  factory _QueryAction.setState(QueryState<T> state) =>
      _QueryAction._(type: QueryActionType.setState, newState: state);
}
