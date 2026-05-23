import 'package:flutter/widgets.dart';
import 'package:tanquery/tanquery.dart';
import '../provider.dart';

/// Configuration for a single query within a [QueriesBuilder].
///
/// Groups a query key, fetch function, and basic options into one object
/// so multiple queries can be declared as a list.
final class QueryConfig<T> {
  /// Unique key identifying this query in the cache.
  final QueryKey key;

  /// Function that fetches the data for this query.
  final QueryFn<T> fn;

  /// How long fetched data is considered fresh. Defaults to [Duration.zero].
  final Duration staleTime;

  /// Whether this query should automatically fetch. Defaults to `true`.
  final bool enabled;

  /// Creates a query configuration.
  const QueryConfig({
    required this.key,
    required this.fn,
    this.staleTime = Duration.zero,
    this.enabled = true,
  });
}

/// Signature for the builder function passed to [QueriesBuilder].
///
/// Receives a list of [QueryObserverResult] values, one per query in the
/// same order as the [QueriesBuilder.queries] list.
typedef QueriesWidgetBuilder = Widget Function(
  BuildContext context,
  List<QueryObserverResult> results,
);

/// Observes multiple queries at once and rebuilds when any of them change.
///
/// Useful when a widget depends on several independent data sources.
/// Each query runs its own observer, and the widget rebuilds whenever
/// any query's state updates.
///
/// ```dart
/// QueriesBuilder(
///   queries: [
///     QueryConfig(key: QueryKey(['users']), fn: () => api.getUsers()),
///     QueryConfig(key: QueryKey(['posts']), fn: () => api.getPosts()),
///   ],
///   builder: (context, results) {
///     final users = results[0];
///     final posts = results[1];
///     if (users.isLoading || posts.isLoading) {
///       return CircularProgressIndicator();
///     }
///     return MyWidget(users: users.data, posts: posts.data);
///   },
/// )
/// ```
class QueriesBuilder extends StatefulWidget {
  /// List of query configurations to observe. Results are returned in the
  /// same order in the builder callback.
  final List<QueryConfig> queries;

  /// Builder called whenever any query's state changes.
  final QueriesWidgetBuilder builder;

  /// Creates a [QueriesBuilder] that observes multiple queries simultaneously.
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
