import 'package:flutter/widgets.dart';
import 'package:tanquery/tanquery.dart';
import '../provider.dart';

/// Signature for the builder function passed to [QueryBuilder].
///
/// Receives the current [QueryObserverResult] as [state], which contains
/// `data`, `error`, `isLoading`, `isFetching`, and other status fields.
typedef QueryWidgetBuilder<T> = Widget Function(
  BuildContext context,
  QueryObserverResult<T> state,
);

/// Builds a widget that reacts to a single query's state.
///
/// Automatically fetches when the widget mounts (if data is stale or missing),
/// refetches on window focus and reconnect, and rebuilds when state changes.
///
/// ```dart
/// QueryBuilder<List<Todo>>(
///   queryKey: QueryKey(['todos']),
///   queryFn: () => api.fetchTodos(),
///   builder: (context, state) {
///     if (state.isLoading) return CircularProgressIndicator();
///     return ListView(children: state.data!.map(TodoTile.new).toList());
///   },
/// )
/// ```
class QueryBuilder<T> extends StatefulWidget {
  /// Unique key identifying this query in the cache.
  final QueryKey queryKey;

  /// Function that fetches the data. Called when the query is stale or missing.
  final QueryFn<T> queryFn;

  /// Builder called whenever the query state changes.
  final QueryWidgetBuilder<T> builder;

  /// How long fetched data is considered fresh. Defaults to [Duration.zero],
  /// meaning data is immediately stale after fetching.
  final Duration staleTime;

  /// How long inactive query data stays in the cache before garbage collection.
  /// Defaults to 5 minutes.
  final Duration gcTime;

  /// Whether the query should automatically fetch. Set to `false` to create
  /// a dependent query that waits until some condition is met.
  final bool enabled;

  /// Static placeholder shown while the first fetch is in progress.
  final T? placeholderData;

  /// Dynamic placeholder derived from [previousData] and [previousQuery].
  /// Takes precedence over [placeholderData] when non-null.
  final T? Function(T? previousData, Query? previousQuery)? placeholderDataFn;

  /// Transforms the raw query data before passing it to [builder].
  /// Useful for picking a subset of the response.
  final T Function(T data)? select;

  /// When set, the query refetches on this interval while the widget is mounted.
  final Duration? refetchInterval;

  /// Number of times to retry a failed fetch before giving up. Defaults to 3.
  final int retryCount;

  /// Controls fetch behavior based on network availability.
  /// Defaults to [NetworkMode.online].
  final NetworkMode networkMode;

  /// Creates a [QueryBuilder] that manages a single query lifecycle.
  const QueryBuilder({
    super.key,
    required this.queryKey,
    required this.queryFn,
    required this.builder,
    this.staleTime = Duration.zero,
    this.gcTime = const Duration(minutes: 5),
    this.enabled = true,
    this.placeholderData,
    this.placeholderDataFn,
    this.select,
    this.refetchInterval,
    this.retryCount = 3,
    this.networkMode = NetworkMode.online,
  });

  @override
  State<QueryBuilder<T>> createState() => _QueryBuilderState<T>();
}

class _QueryBuilderState<T> extends State<QueryBuilder<T>> {
  QueryObserver<T>? _observer;
  Unsubscribe? _unsubscribe;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_observer == null) {
      _createObserver();
      _subscribe();
    }
  }

  @override
  void didUpdateWidget(QueryBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.queryKey != widget.queryKey ||
        oldWidget.staleTime != widget.staleTime ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.refetchInterval != widget.refetchInterval ||
        oldWidget.retryCount != widget.retryCount ||
        oldWidget.networkMode != widget.networkMode ||
        oldWidget.gcTime != widget.gcTime ||
        !identical(oldWidget.queryFn, widget.queryFn) ||
        !identical(oldWidget.select, widget.select) ||
        !identical(oldWidget.placeholderData, widget.placeholderData) ||
        !identical(oldWidget.placeholderDataFn, widget.placeholderDataFn);
    if (changed) {
      _unsubscribe?.call();
      _observer?.destroy();
      _createObserver();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _observer?.destroy();
    super.dispose();
  }

  void _createObserver() {
    final client = DartQuery.of(context);
    _observer = QueryObserver<T>(
      cache: client.getQueryCache(),
      queryKey: widget.queryKey,
      queryFn: widget.queryFn,
      staleTime: widget.staleTime,
      gcTime: widget.gcTime,
      enabled: widget.enabled,
      placeholderData: widget.placeholderData,
      placeholderDataFn: widget.placeholderDataFn,
      select: widget.select,
      refetchInterval: widget.refetchInterval,
      retryCount: widget.retryCount,
      networkMode: widget.networkMode,
    );
  }

  void _subscribe() {
    _unsubscribe = _observer!.subscribe((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_observer == null) return const SizedBox.shrink();
    return widget.builder(context, _observer!.currentResult);
  }
}
