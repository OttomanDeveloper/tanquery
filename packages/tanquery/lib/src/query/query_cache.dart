import '../core/focus_manager.dart' as fm;
import '../core/notify_manager.dart' as nm;
import '../core/online_manager.dart' as om;
import '../core/subscribable.dart';
import '../models/query_key.dart';
import '../models/types.dart';
import '../utils/hash_key.dart';
import '../utils/match.dart';
import 'query.dart';

/// Describes a lifecycle event emitted by the [QueryCache].
///
/// Listeners receive these when queries are added, removed, updated,
/// or when observers attach/detach.
final class QueryCacheEvent {
  /// What happened (added, removed, updated, observerAdded, observerRemoved).
  final EventType type;

  /// The query this event relates to.
  final Query query;

  /// For [EventType.updated], the action that triggered the state change.
  final Object? action;

  /// For observer events, the observer that was added or removed.
  final Object? observer;

  const QueryCacheEvent({
    required this.type,
    required this.query,
    this.action,
    this.observer,
  });
}

/// Callback signature for [QueryCache] event listeners.
typedef QueryCacheListener = void Function(QueryCacheEvent event);

/// In-memory store of all active queries, keyed by their hash.
///
/// Handles building new queries (or returning existing ones), partial key
/// matching for bulk operations, and forwarding lifecycle events to listeners.
class QueryCache extends Subscribable<QueryCacheListener> {
  final Map<String, Query> _queries = {};
  final nm.NotifyManager _notifyManager;
  final fm.FocusManager? _focusManager;
  final om.OnlineManager? _onlineManager;

  /// Called after a query transitions to the success state.
  final void Function(Object? data, Query query)? onSuccess;

  /// Called after a query transitions to the error state.
  final void Function(Object? error, Query query)? onError;

  /// Called after a query reaches either success or error state.
  final void Function(Object? data, Object? error, Query query)? onSettled;

  QueryCache({
    nm.NotifyManager? notifyManager,
    fm.FocusManager? focusManager,
    om.OnlineManager? onlineManager,
    this.onSuccess,
    this.onError,
    this.onSettled,
  })  : _notifyManager = notifyManager ?? nm.notifyManager,
        _focusManager = focusManager,
        _onlineManager = onlineManager;

  /// Returns an existing query matching [queryKey], or creates a new one.
  ///
  /// If the query already exists, its options are not overwritten. Use
  /// [Query.setOptions] to update options on an existing query.
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
        focusManager: _focusManager,
        onlineManager: _onlineManager,
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

  /// Destroys a query and removes it from the cache.
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

  /// Removes and destroys all queries in the cache.
  void clear() {
    _notifyManager.batch(() {
      for (final query in getAll()) {
        remove(query);
      }
    });
  }

  /// Looks up a single query by its exact [queryHash]. Returns null if not found.
  Query? get(String queryHash) => _queries[queryHash];

  /// Returns all queries currently in the cache as a list.
  List<Query> getAll() => _queries.values.toList();

  /// Finds the first query matching the given filters, or null if none match.
  ///
  /// When [exact] is true, the [queryKey] must match exactly. Otherwise,
  /// partial key matching is used (the query just needs to start with
  /// the provided key parts).
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

  /// Returns all queries matching the given filters.
  ///
  /// With no filters, returns everything. Supports filtering by [queryKey]
  /// (partial match by default), [type] (active/inactive/all), [stale] status,
  /// [fetchStatus], and a custom [predicate].
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

  /// Notifies all cached queries that the app window regained focus.
  void onFocus() {
    _notifyManager.batch(() {
      for (final query in getAll()) {
        query.onFocus();
      }
    });
  }

  /// Notifies all cached queries that network connectivity was restored.
  void onOnline() {
    _notifyManager.batch(() {
      for (final query in getAll()) {
        query.onOnline();
      }
    });
  }
}
