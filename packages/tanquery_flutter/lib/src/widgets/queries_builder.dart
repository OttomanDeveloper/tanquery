import 'package:flutter/widgets.dart';
import 'package:tanquery/tanquery.dart';
import '../provider.dart';

class QueryConfig<T> {
  final QueryKey key;
  final QueryFn<T> fn;
  final Duration staleTime;
  final bool enabled;

  const QueryConfig({
    required this.key,
    required this.fn,
    this.staleTime = Duration.zero,
    this.enabled = true,
  });
}

typedef QueriesWidgetBuilder = Widget Function(
  BuildContext context,
  List<QueryObserverResult> results,
);

class QueriesBuilder extends StatefulWidget {
  final List<QueryConfig> queries;
  final QueriesWidgetBuilder builder;

  const QueriesBuilder({
    super.key,
    required this.queries,
    required this.builder,
  });

  @override
  State<QueriesBuilder> createState() => _QueriesBuilderState();
}

class _QueriesBuilderState extends State<QueriesBuilder> {
  final List<QueryObserver> _observers = [];
  final List<Unsubscribe> _unsubscribes = [];

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _createObservers();
    }
  }

  @override
  void didUpdateWidget(QueriesBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_queriesChanged(oldWidget.queries, widget.queries)) {
      _disposeObservers();
      _createObservers();
    }
  }

  @override
  void dispose() {
    _disposeObservers();
    super.dispose();
  }

  bool _queriesChanged(List<QueryConfig> old, List<QueryConfig> current) {
    if (old.length != current.length) return true;
    for (var i = 0; i < old.length; i++) {
      if (old[i].key != current[i].key ||
          old[i].staleTime != current[i].staleTime ||
          old[i].enabled != current[i].enabled) return true;
    }
    return false;
  }

  void _createObservers() {
    final client = DartQuery.of(context);
    for (final config in widget.queries) {
      final observer = QueryObserver(
        cache: client.getQueryCache(),
        queryKey: config.key,
        queryFn: config.fn,
        staleTime: config.staleTime,
        enabled: config.enabled,
      );
      _observers.add(observer);
      _unsubscribes.add(observer.subscribe((_) {
        if (mounted) setState(() {});
      }));
    }
  }

  void _disposeObservers() {
    for (final unsub in _unsubscribes) {
      unsub();
    }
    for (final observer in _observers) {
      observer.destroy();
    }
    _observers.clear();
    _unsubscribes.clear();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _observers.map((o) => o.currentResult).toList(),
    );
  }
}
