import '../models/query_key.dart';
import '../query/query.dart';
import '../query_client.dart';

class DehydratedQuery {
  final String queryHash;
  final List<Object?> queryKey;
  final Map<String, Object?> state;
  final DateTime? dehydratedAt;
  final String? queryType;

  const DehydratedQuery({
    required this.queryHash,
    required this.queryKey,
    required this.state,
    this.dehydratedAt,
    this.queryType,
  });

  Map<String, dynamic> toJson() => {
        'queryHash': queryHash,
        'queryKey': queryKey,
        'state': state,
        if (dehydratedAt != null) 'dehydratedAt': dehydratedAt!.millisecondsSinceEpoch,
        if (queryType != null) 'queryType': queryType,
      };

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

class DehydratedState {
  final List<DehydratedQuery> queries;

  const DehydratedState({this.queries = const []});

  Map<String, dynamic> toJson() => {
        'queries': queries.map((q) => q.toJson()).toList(),
      };

  factory DehydratedState.fromJson(Map<String, dynamic> json) => DehydratedState(
        queries: (json['queries'] as List?)
                ?.map((q) => DehydratedQuery.fromJson(Map<String, dynamic>.from(q as Map)))
                .toList() ??
            [],
      );
}

class DehydrateOptions {
  final bool Function(Query query)? shouldDehydrateQuery;
  final bool shouldRedactErrors;
  const DehydrateOptions({this.shouldDehydrateQuery, this.shouldRedactErrors = true});
}

bool defaultShouldDehydrateQuery(Query query) => query.state.isSuccess;

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

