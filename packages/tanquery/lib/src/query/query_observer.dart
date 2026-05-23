import 'dart:async';
import '../core/focus_manager.dart' as fm;
import '../core/notify_manager.dart' as nm;
import '../core/subscribable.dart';
import '../models/query_key.dart';
import '../models/query_state.dart';
import '../models/types.dart';
import '../utils/time_utils.dart';
import 'query.dart';
import 'query_cache.dart';

class QueryObserverResult<TData> {
  final TData? data;
  final Object? error;
  final QueryStatus status;
  final FetchStatus fetchStatus;
  final bool isLoading;
  final bool isFetching;
  final bool isPaused;
  final bool isError;
  final bool isSuccess;
  final bool isPending;
  final bool isStale;
  final bool isPlaceholderData;
  final bool isFetched;
  final bool isFetchedAfterMount;
  final bool isRefetching;
  final bool isLoadingError;
  final bool isRefetchError;
  final DateTime? dataUpdatedAt;
  final int failureCount;
  final Object? failureReason;
  final int errorUpdateCount;

  const QueryObserverResult({
    this.data,
    this.error,
    this.status = QueryStatus.pending,
    this.fetchStatus = FetchStatus.idle,
    this.isLoading = false,
    this.isFetching = false,
    this.isPaused = false,
    this.isError = false,
    this.isSuccess = false,
    this.isPending = true,
    this.isStale = true,
    this.isPlaceholderData = false,
    this.isFetched = false,
    this.isFetchedAfterMount = false,
    this.isRefetching = false,
    this.isLoadingError = false,
    this.isRefetchError = false,
    this.dataUpdatedAt,
    this.failureCount = 0,
    this.failureReason,
    this.errorUpdateCount = 0,
  });
}

typedef QueryObserverListener<TData> = void Function(QueryObserverResult<TData> result);

class QueryObserver<TData> extends Subscribable<Function> implements QueryUpdateCallback {
  final QueryCache _cache;
  final nm.NotifyManager _notifyManager;
  final fm.FocusManager _focusManager;

  QueryKey _queryKey;
  QueryFn<TData> _queryFn;
  Duration _staleTime;
  Duration _gcTime;
  bool _enabled;
  TData? _placeholderData;
  TData? Function(TData? previousData, Query? previousQuery)? _placeholderDataFn;
  TData Function(TData data)? _select;
  Duration? _refetchInterval;
  int _retryCount;
  NetworkMode _networkMode;

  Query<TData>? _currentQuery;
  QueryObserverResult<TData> _currentResult = const QueryObserverResult();
  QueryState? _currentQueryInitialState;
  Query? _lastQueryWithDefinedData;

  // Select memoization
  TData Function(TData)? _selectFn;
  TData? _selectResult;
  Object? _selectInput;

  Timer? _staleTimer;
  Timer? _refetchTimer;

  QueryObserver({
    required QueryCache cache,
    required QueryKey queryKey,
    required QueryFn<TData> queryFn,
    Duration staleTime = Duration.zero,
    Duration gcTime = const Duration(minutes: 5),
    bool enabled = true,
    TData? placeholderData,
    TData? Function(TData? previousData, Query? previousQuery)? placeholderDataFn,
    TData Function(TData data)? select,
    Duration? refetchInterval,
    int retryCount = 3,
    NetworkMode networkMode = NetworkMode.online,
    nm.NotifyManager? notifyManager,
    fm.FocusManager? focusManager,
  })  : _cache = cache,
        _queryKey = queryKey,
        _queryFn = queryFn,
        _staleTime = staleTime,
        _gcTime = gcTime,
        _enabled = enabled,
        _placeholderData = placeholderData,
        _placeholderDataFn = placeholderDataFn,
        _select = select,
        _refetchInterval = refetchInterval,
        _retryCount = retryCount,
        _networkMode = networkMode,
        _notifyManager = notifyManager ?? nm.notifyManager,
        _focusManager = focusManager ?? fm.focusManager {
    _updateQuery();
    updateResult();
  }

  QueryObserverResult<TData> get currentResult => _currentResult;

  // --- Subscribable lifecycle ---

  @override
  void onSubscribe() {
    if (listeners.length == 1) {
      _currentQuery?.addObserver(this);
      if (_shouldFetchOnMount()) {
        _executeFetch();
      } else {
        updateResult();
      }
      _updateTimers();
    }
  }

  @override
  void onUnsubscribe() {
    if (!hasListeners) {
      destroy();
    }
  }

  // --- QueryUpdateCallback ---

  @override
  void onQueryUpdate() {
    updateResult();
    if (hasListeners) {
      _updateTimers();
    }
  }

  @override
  bool shouldFetchOnWindowFocus() {
    return _enabled && _currentQuery != null && _isStale();
  }

  @override
  bool shouldFetchOnReconnect() {
    return _enabled && _currentQuery != null && _isStale();
  }

  @override
  Future<void> refetch({bool cancelRefetch = true}) {
    return _executeFetch(cancelRefetch: cancelRefetch);
  }

  // --- Result computation ---

  void updateResult() {
    final prevResult = _currentResult;
    _currentResult = _createResult();
    if (_currentQuery?.state.data != null) {
      _lastQueryWithDefinedData = _currentQuery;
    }

    if (!_shallowEqual(prevResult, _currentResult)) {
      _notifyListeners();
    }
  }

  QueryObserverResult<TData> _createResult() {
    final query = _currentQuery;
    if (query == null) return const QueryObserverResult();

    final state = query.state;
    var status = state.status;
    var fetchStatus = state.fetchStatus;
    var data = state.data;
    var error = state.error;
    var isPlaceholderData = false;

    // Placeholder data
    if (data == null && status == QueryStatus.pending) {
      TData? placeholder;
      if (_placeholderDataFn != null) {
        placeholder = _placeholderDataFn!(
          _lastQueryWithDefinedData?.state.data as TData?,
          _lastQueryWithDefinedData,
        );
      } else if (_placeholderData != null) {
        placeholder = _placeholderData;
      }

      if (placeholder != null) {
        data = placeholder;
        status = QueryStatus.success;
        isPlaceholderData = true;
      }
    }

    // Select transformation with memoization
    if (_select != null && data != null && !isPlaceholderData) {
      if (identical(_selectFn, _select) && identical(_selectInput, state.data)) {
        data = _selectResult;
      } else {
        try {
          _selectFn = _select;
          _selectInput = state.data;
          data = _select!(data);
          _selectResult = data;
        } catch (e) {
          error = e;
          status = QueryStatus.error;
        }
      }
    }

    final isPending = status == QueryStatus.pending;
    final isSuccess = status == QueryStatus.success;
    final isError = status == QueryStatus.error;
    final isFetching = fetchStatus == FetchStatus.fetching;
    final isLoading = isPending && isFetching;
    final hasData = data != null;
    final isStale = _isStale();

    final initialState = _currentQueryInitialState;
    final isFetchedAfterMount = initialState != null &&
        (state.dataUpdateCount > initialState.dataUpdateCount ||
            state.errorUpdateCount > initialState.errorUpdateCount);

    return QueryObserverResult<TData>(
      data: data,
      error: error,
      status: status,
      fetchStatus: fetchStatus,
      isLoading: isLoading,
      isFetching: isFetching,
      isPaused: fetchStatus == FetchStatus.paused,
      isError: isError,
      isSuccess: isSuccess,
      isPending: isPending,
      isStale: isStale,
      isPlaceholderData: isPlaceholderData,
      isFetched: query.isFetched(),
      isFetchedAfterMount: isFetchedAfterMount,
      isRefetching: isFetching && !isPending,
      isLoadingError: isError && !hasData,
      isRefetchError: isError && hasData,
      dataUpdatedAt: state.dataUpdatedAt,
      failureCount: state.fetchFailureCount,
      failureReason: state.fetchFailureReason,
      errorUpdateCount: state.errorUpdateCount,
    );
  }

  // --- Fetch ---

  Future<void> _executeFetch({bool cancelRefetch = true}) async {
    _updateQuery();
    try {
      await _currentQuery?.fetch(cancelRefetch: cancelRefetch);
    } catch (_) {}
  }

  // --- Query management ---

  void _updateQuery() {
    final query = _cache.build<TData>(
      queryKey: _queryKey,
      queryFn: _queryFn,
      gcTime: _gcTime,
      retryCount: _retryCount,
      networkMode: _networkMode,
    );
    if (query != _currentQuery) {
      _currentQuery?.removeObserver(this);
      _currentQuery = query;
      _currentQueryInitialState = query.state;
      if (hasListeners) {
        query.addObserver(this);
      }
    }
    query.setOptions(
      queryFn: _queryFn,
      retryCount: _retryCount,
      networkMode: _networkMode,
    );
  }

  // --- Timers ---

  void _updateTimers() {
    _updateStaleTimer();
    _updateRefetchInterval();
  }

  void _updateStaleTimer() {
    _staleTimer?.cancel();
    _staleTimer = null;

    if (_currentResult.isStale || _staleTime == Duration.zero) return;
    if (_currentQuery?.state.dataUpdatedAt == null) return;

    final remaining = timeUntilStale(_currentQuery!.state.dataUpdatedAt!, _staleTime);
    if (remaining > Duration.zero) {
      _staleTimer = Timer(remaining + const Duration(milliseconds: 1), () {
        if (!_currentResult.isStale) {
          updateResult();
        }
      });
    }
  }

  void _updateRefetchInterval() {
    _refetchTimer?.cancel();
    _refetchTimer = null;

    if (!_enabled || _refetchInterval == null || _refetchInterval == Duration.zero) return;

    _refetchTimer = Timer.periodic(_refetchInterval!, (_) {
      if (_focusManager.isFocused()) {
        _executeFetch();
      }
    });
  }

  // --- Staleness ---

  bool _isStale() {
    if (!_enabled) return false;
    if (_currentQuery == null) return true;
    return _currentQuery!.isStaleByTime(_staleTime);
  }

  bool _shouldFetchOnMount() {
    if (!_enabled) return false;
    final query = _currentQuery;
    if (query == null) return false;
    if (query.state.data == null && query.state.status != QueryStatus.error) return true;
    if (query.state.data != null && _isStale()) return true;
    return false;
  }

  // --- Notify ---

  void _notifyListeners() {
    _notifyManager.batch(() {
      for (final listener in listeners) {
        (listener as QueryObserverListener<TData>)(_currentResult);
      }
    });
  }

  bool _shallowEqual(QueryObserverResult a, QueryObserverResult b) {
    return identical(a.data, b.data) &&
        a.status == b.status &&
        a.fetchStatus == b.fetchStatus &&
        a.isStale == b.isStale &&
        a.isPlaceholderData == b.isPlaceholderData &&
        identical(a.error, b.error);
  }

  // --- Cleanup ---

  void destroy() {
    _staleTimer?.cancel();
    _staleTimer = null;
    _refetchTimer?.cancel();
    _refetchTimer = null;
    _currentQuery?.removeObserver(this);
  }
}
