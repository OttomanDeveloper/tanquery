import '../core/notify_manager.dart' as nm;
import '../core/subscribable.dart';
import '../models/query_key.dart';
import '../models/types.dart';
import '../utils/hash_key.dart';
import '../utils/match.dart';
import 'query.dart';

class QueryCacheEvent {
  final EventType type;
  final Query query;
  final Object? action;
  final Object? observer;

  const QueryCacheEvent({
    required this.type,
    required this.query,
    this.action,
    this.observer,
  });
}

typedef QueryCacheListener = void Function(QueryCacheEvent event);

class QueryCache extends Subscribable<QueryCacheListener> {
  final Map<String, Query> _queries = {};
  final nm.NotifyManager _notifyManager;

  final void Function(Object? data, Query query)? onSuccess;
  final void Function(Object? error, Query query)? onError;
  final void Function(Object? data, Object? error, Query query)? onSettled;

  QueryCache({
    nm.NotifyManager? notifyManager,
    this.onSuccess,
    this.onError,
    this.onSettled,
  }) : _notifyManager = notifyManager ?? nm.notifyManager;

  Query<TData> build<TData>({
    required QueryKey queryKey,
    QueryFn<TData>? queryFn,
    TData? initialData,
    DateTime? initialDataUpdatedAt,
    Duration gcTime = const Duration(minutes: 5),
    int retryCount = 3,
    Duration Function(int)? retryDelay,
    bool Function(Object)? retryCondition,
    NetworkMode networkMode = NetworkMode.online,
    bool structuralSharing = true,
    Map<String, Object?>? meta,
    String? queryType,
    String? queryHash,
  }) {
    final hash = queryHash ?? hashQueryKey(queryKey.parts);
    var query = _queries[hash] as Query<TData>?;
    if (query == null) {
      query = Query<TData>(
        queryKey: queryKey,
        queryHash: hash,
        queryFn: queryFn,
        initialData: initialData,
        initialDataUpdatedAt: initialDataUpdatedAt,
        gcTime: gcTime,
        retryCount: retryCount,
        retryDelay: retryDelay,
        retryCondition: retryCondition,
        networkMode: networkMode,
        structuralSharing: structuralSharing,
        meta: meta,
        queryType: queryType,
        notifyManager: _notifyManager,
        cacheNotify: (event) => _handleQueryNotify(event),
      );
      query.onRemove = () => remove(query!);
      _add(query);
    }
    return query;
  }

  void _add(Query query) {
    if (!_queries.containsKey(query.queryHash)) {
      _queries[query.queryHash] = query;
      _notify(QueryCacheEvent(type: EventType.added, query: query));
    }
  }

  void remove(Query query) {
    final existing = _queries[query.queryHash];
    if (existing != null) {
      query.destroy();
      if (identical(existing, query)) {
        _queries.remove(query.queryHash);
      }
      _notify(QueryCacheEvent(type: EventType.removed, query: query));
    }
  }

  void clear() {
    _notifyManager.batch(() {
      for (final query in getAll()) {
        remove(query);
      }
    });
  }

  Query? get(String queryHash) => _queries[queryHash];

  List<Query> getAll() => _queries.values.toList();

  Query? find({
    QueryKey? queryKey,
    bool exact = true,
    QueryTypeFilter type = QueryTypeFilter.all,
    bool? stale,
    FetchStatus? fetchStatus,
    bool Function(Query)? predicate,
  }) {
    return getAll().cast<Query?>().firstWhere(
          (query) => _matchQuery(
            query: query!,
            queryKey: queryKey,
            exact: exact,
            type: type,
            stale: stale,
            fetchStatus: fetchStatus,
            predicate: predicate,
          ),
          orElse: () => null,
        );
  }

  List<Query> findAll({
    QueryKey? queryKey,
    bool exact = false,
    QueryTypeFilter type = QueryTypeFilter.all,
    bool? stale,
    FetchStatus? fetchStatus,
    bool Function(Query)? predicate,
  }) {
    final queries = getAll();
    if (queryKey == null &&
        type == QueryTypeFilter.all &&
        stale == null &&
        fetchStatus == null &&
        predicate == null) {
      return queries;
    }
    return queries
        .where((query) => _matchQuery(
              query: query,
              queryKey: queryKey,
              exact: exact,
              type: type,
              stale: stale,
              fetchStatus: fetchStatus,
              predicate: predicate,
            ))
        .toList();
  }

  bool _matchQuery({
    required Query query,
    QueryKey? queryKey,
    bool exact = false,
    QueryTypeFilter type = QueryTypeFilter.all,
    bool? stale,
    FetchStatus? fetchStatus,
    bool Function(Query)? predicate,
  }) {
    if (queryKey != null) {
      if (exact) {
        if (query.queryHash != hashQueryKey(queryKey.parts)) return false;
      } else {
        if (!partialMatchKey(query.queryKey.parts, queryKey.parts)) {
          return false;
        }
      }
    }

    if (type == QueryTypeFilter.active && !query.isActive()) return false;
    if (type == QueryTypeFilter.inactive && query.isActive()) return false;

    if (stale != null) {
      final queryIsStale = query.isStaleByTime(Duration.zero);
      if (stale != queryIsStale) return false;
    }

    if (fetchStatus != null) {
      if (query.state.fetchStatus != fetchStatus) return false;
    }

    if (predicate != null && !predicate(query)) return false;

    return true;
  }

  void _notify(QueryCacheEvent event) {
    _notifyManager.batch(() {
      for (final listener in listeners) {
        listener(event);
      }
    });
  }

  void _handleQueryNotify(Object event) {
    if (event is Map<String, Object?>) {
      final query = event['query'] as Query;
      final type = event['type'] as EventType;
      _notify(QueryCacheEvent(
        type: type,
        query: query,
        action: event['action'],
        observer: event['observer'],
      ));

      // Fire config callbacks on query state changes
      if (type == EventType.updated) {
        if (query.state.isSuccess) {
          onSuccess?.call(query.state.data, query);
        }
        if (query.state.isError) {
          onError?.call(query.state.error, query);
        }
        if (query.state.isSuccess || query.state.isError) {
          onSettled?.call(query.state.data, query.state.error, query);
        }
      }
    }
  }

  void onFocus() {
    _notifyManager.batch(() {
      for (final query in getAll()) {
        query.onFocus();
      }
    });
  }

  void onOnline() {
    _notifyManager.batch(() {
      for (final query in getAll()) {
        query.onOnline();
      }
    });
  }
}
