import 'package:flutter/widgets.dart';
import 'package:tanquery/tanquery.dart';
import '../provider.dart';

typedef QueryWidgetBuilder<T> = Widget Function(
  BuildContext context,
  QueryObserverResult<T> state,
);

class QueryBuilder<T> extends StatefulWidget {
  final QueryKey queryKey;
  final QueryFn<T> queryFn;
  final QueryWidgetBuilder<T> builder;
  final Duration staleTime;
  final Duration gcTime;
  final bool enabled;
  final T? placeholderData;
  final T? Function(T? previousData, Query? previousQuery)? placeholderDataFn;
  final T Function(T data)? select;
  final Duration? refetchInterval;
  final int retryCount;
  final NetworkMode networkMode;

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
