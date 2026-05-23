import '../models/query_key.dart';
import '../query/query.dart';
import '../query_client.dart';

/// Snapshot of a single query's state, serializable to JSON.
///
/// Created by [dehydrate] and consumed by [hydrate] to move cache state
/// into and out of persistent storage.
final class DehydratedQuery {
  /// Hash string that uniquely identifies this query in the cache.
  final String queryHash;

  /// Original key parts used to build [queryHash].
  final List<Object?> queryKey;

  /// Serialized query state (data, status, error, etc.).
  final Map<String, Object?> state;

  /// When this snapshot was taken. Used to resolve conflicts during hydration.
  final DateTime? dehydratedAt;

  /// Optional type tag (e.g. "infinite") so the cache can reconstruct
  /// the correct query subclass.
  final String? queryType;

  /// Creates a dehydrated query snapshot.
  const DehydratedQuery({
    required this.queryHash,
    required this.queryKey,
    required this.state,
    this.dehydratedAt,
    this.queryType,
  });

  /// Converts this snapshot to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'queryHash': queryHash,
        'queryKey': queryKey,
        'state': state,
        if (dehydratedAt != null) 'dehydratedAt': dehydratedAt!.millisecondsSinceEpoch,
        if (queryType != null) 'queryType': queryType,
      };

  /// Reconstructs a [DehydratedQuery] from a JSON map.
  factory DehydratedQuery.fromJson(Map<String, dynamic> json) => DehydratedQuery(
        queryHash: json['queryHash'] as String,
        queryKey: (json['queryKey'] as List).cast<Object?>(),
        state: Map<String, Object?>.from(json['state'] as Map),
        dehydratedAt: json['dehydratedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['dehydratedAt'] as int)
            : null,
        queryType: json['queryType'] as String?,
      );
}

/// Collection of [DehydratedQuery] snapshots representing the full
/// dehydrated cache state.
final class DehydratedState {
  /// The dehydrated queries in this state snapshot.
  final List<DehydratedQuery> queries;

  /// Creates a dehydrated state, defaulting to an empty list.
  const DehydratedState({this.queries = const []});

  /// Converts the full state to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'queries': queries.map((q) => q.toJson()).toList(),
      };

  /// Reconstructs a [DehydratedState] from a JSON map.
  factory DehydratedState.fromJson(Map<String, dynamic> json) => DehydratedState(
        queries: (json['queries'] as List?)
                ?.map((q) => DehydratedQuery.fromJson(Map<String, dynamic>.from(q as Map)))
                .toList() ??
            [],
      );
}

/// Controls which queries get dehydrated and whether error details are kept.
final class DehydrateOptions {
  /// Filter predicate. Only queries where this returns true are included.
  /// Defaults to [defaultShouldDehydrateQuery] when null.
  final bool Function(Query query)? shouldDehydrateQuery;

  /// When true (the default), error messages are replaced with null in the
  /// dehydrated state to avoid leaking internal details into storage.
  final bool shouldRedactErrors;

  /// Creates dehydration options.
  const DehydrateOptions({this.shouldDehydrateQuery, this.shouldRedactErrors = true});
}

/// Default filter that only dehydrates queries with successful data.
///
/// Queries in error or loading states are skipped since they have no
/// useful data to persist.
bool defaultShouldDehydrateQuery(Query query) => query.state.isSuccess;

/// Extracts a serializable snapshot of the query cache from [client].
///
/// Walks every query in the cache, applies the filter from [options]
/// (defaulting to [defaultShouldDehydrateQuery]), and returns a
/// [DehydratedState] that can be serialized to JSON and saved to storage.
DehydratedState dehydrate(QueryClient client, [DehydrateOptions? options]) {
  final queryCache = client.getQueryCache();
  final shouldDehydrate = options?.shouldDehydrateQuery ?? defaultShouldDehydrateQuery;
  final shouldRedactErrors = options?.shouldRedactErrors ?? true;

  final queries = queryCache
      .getAll()
      .where(shouldDehydrate)
      .map((query) => DehydratedQuery(
            queryHash: query.queryHash,
            queryKey: query.queryKey.parts,
            state: {
              'data': query.state.data,
              'status': query.state.status.name,
              'dataUpdatedAt': query.state.dataUpdatedAt?.millisecondsSinceEpoch,
              'error': shouldRedactErrors ? null : query.state.error?.toString(),
              'isInvalidated': query.state.isInvalidated,
            },
            dehydratedAt: DateTime.now(),
            queryType: query.queryType,
          ))
      .toList();

  return DehydratedState(queries: queries);
}

/// Restores previously dehydrated queries into [client]'s cache.
///
/// For each query in [dehydratedState], if it already exists in the cache
/// the data is updated only when the dehydrated version is newer. If it
/// does not exist, a new cache entry is created.
void hydrate(QueryClient client, DehydratedState dehydratedState) {
  final queryCache = client.getQueryCache();

  for (final dq in dehydratedState.queries) {
    final existing = queryCache.get(dq.queryHash);
    final dataUpdatedAt = dq.state['dataUpdatedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(dq.state['dataUpdatedAt'] as int)
        : null;

    if (existing != null) {
      if (dataUpdatedAt != null &&
          existing.state.dataUpdatedAt != null &&
          dataUpdatedAt.isAfter(existing.state.dataUpdatedAt!)) {
        existing.setData(dq.state['data'], updatedAt: dataUpdatedAt, manual: true);
      }
    } else {
      queryCache.build(
        queryKey: QueryKey(dq.queryKey),
        queryHash: dq.queryHash,
        initialData: dq.state['data'],
        initialDataUpdatedAt: dataUpdatedAt,
        queryType: dq.queryType,
      );
    }
  }
}

