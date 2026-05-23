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

typedef QueryFn<T> = Future<T> Function();

abstract class QueryUpdateCallback {
  void onQueryUpdate();
  bool shouldFetchOnWindowFocus() => false;
  bool shouldFetchOnReconnect() => false;
  Future<void> refetch({bool cancelRefetch});
}

typedef CacheNotifyFn = void Function(Object event);

class Query<TData> extends Removable {
  final QueryKey queryKey;
  final String queryHash;
  final nm.NotifyManager _notifyManager;
  final fm.FocusManager _focusManager;
  final om.OnlineManager _onlineManager;

  CacheNotifyFn? _cacheNotify;

  QueryState<TData> state;
  QueryState<TData> _initialState;
  QueryState<TData>? _revertState;

  final List<QueryUpdateCallback> _observers = [];
  Retryer<TData>? _retryer;

  void Function()? onRemove;

  QueryFn<TData>? queryFn;
  int retryCount;
  Duration Function(int) retryDelay;
  bool Function(Object)? retryCondition;
  NetworkMode networkMode;
  bool structuralSharing;
  String? _queryType;
  Map<String, Object?>? meta;

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

  String? get queryType => _queryType;

  // --- Options ---

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

  TData setData(TData newData, {DateTime? updatedAt, bool manual = false}) {
    final data = structuralSharing
        ? replaceEqualDeep(state.data, newData) as TData
        : newData;
    _dispatch(_QueryAction.success(
        data: data, dataUpdatedAt: updatedAt, manual: manual));
    return data;
  }

  void setState(QueryState<TData> newState) {
    _dispatch(_QueryAction.setState(newState));
  }

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

  void reset() {
    destroy();
    state = _initialState;
  }

  // --- Staleness ---

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

  bool isActive() => _observers.isNotEmpty;

  bool isDisabled() {
    if (_observers.isNotEmpty) return false;
    return isSkipToken(queryFn) || !isFetched();
  }

  bool isFetched() => state.dataUpdateCount + state.errorUpdateCount > 0;

  // --- Observers ---

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

  int get observerCount => _observers.length;
  QueryState<TData> get resetState => _initialState;

  // --- Events ---

  void onFocus() {
    final observer = _observers
        .cast<QueryUpdateCallback?>()
        .firstWhere((o) => o!.shouldFetchOnWindowFocus(), orElse: () => null);
    observer?.refetch(cancelRefetch: false);
    _retryer?.resume();
  }

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
