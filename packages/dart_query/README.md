# dart_query

TanStack Query for Dart. Automatic caching, stale-while-revalidate, background refetching, mutations with optimistic updates, infinite queries, and more.

Pure Dart -- no Flutter dependency. Works with Shelf, Dart Frog, CLI tools, or any Dart environment.

## Features

- **Automatic caching** with configurable stale time and garbage collection
- **Stale-while-revalidate** -- show cached data while silently refetching
- **Background refetching** on app focus, network reconnect, and intervals
- **Mutations** with optimistic updates and rollback
- **Infinite queries** for paginated/cursor-based data
- **Retry with exponential backoff** (1s, 2s, 4s, 8s, 16s, 30s cap)
- **Request deduplication** -- same key = one fetch, N subscribers
- **Hierarchical key invalidation** -- invalidate `['todos']` clears `['todos', 1]` too
- **Streamed queries** for WebSocket, SSE, and LLM streaming
- **Hydration/dehydration** for cache persistence across app restarts
- **Structural sharing** preserves reference identity for unchanged data

## Quick Start

```dart
import 'package:dart_query/dart_query.dart';

final client = QueryClient();
client.mount();

// Fetch data
final data = await client.fetchQuery<String>(
  queryKey: QueryKey(['todos']),
  queryFn: () => api.fetchTodos(),
);

// Cache data manually
client.setQueryData<String>(QueryKey(['user']), userData);

// Invalidate and refetch
await client.invalidateQueries(queryKey: QueryKey(['todos']));

// Prefetch for later
await client.prefetchQuery<String>(
  queryKey: QueryKey(['user', userId]),
  queryFn: () => api.fetchUser(userId),
);
```

## QueryObserver (Reactive)

```dart
final observer = QueryObserver<List<Todo>>(
  cache: client.getQueryCache(),
  queryKey: QueryKey(['todos']),
  queryFn: () => api.fetchTodos(),
  staleTime: Duration(minutes: 5),
);

final unsub = observer.subscribe((result) {
  if (result.isLoading) print('Loading...');
  if (result.isSuccess) print('Data: ${result.data}');
  if (result.isError) print('Error: ${result.error}');
});

// Clean up
unsub();
```

## Mutations

```dart
final mutationCache = client.getMutationCache();
final observer = MutationObserver<Todo, CreateTodoInput>(
  cache: mutationCache,
  config: MutationConfig(
    mutationFn: (input) => api.createTodo(input),
    onSuccess: (data, variables, context) async {
      await client.invalidateQueries(queryKey: QueryKey(['todos']));
    },
  ),
);

// Fire and forget
observer.mutate(CreateTodoInput(title: 'Buy milk'));

// Or await the result
final todo = await observer.mutateAsync(CreateTodoInput(title: 'Buy milk'));
```

## Streamed Queries

```dart
final queryFn = streamedQuery<ChatMessage, List<ChatMessage>>(
  streamFn: () => chatApi.messageStream(roomId),
  reducer: (accumulated, chunk) => [...accumulated, chunk],
  initialValue: [],
  refetchMode: RefetchMode.append,
);
```

## Hydration (Cache Persistence)

```dart
// Save cache
final state = dehydrate(client);
await storage.write('cache', jsonEncode(state.toJson()));

// Restore cache
final json = jsonDecode(await storage.read('cache'));
hydrate(client, DehydratedState.fromJson(json));
```

## For Flutter

See [dart_query_flutter](https://pub.dev/packages/dart_query_flutter) for widget builders (`QueryBuilder`, `MutationBuilder`, `InfiniteQueryBuilder`) and the visual devtools overlay.

## Architecture

Faithfully follows [TanStack Query](https://tanstack.com/query)'s internal architecture:

```
QueryClient (public API)
+-- QueryCache (stores Query instances)
|   +-- Query (state machine with reducer)
|       +-- Retryer (retry with backoff)
+-- MutationCache (scoped sequential execution)
|   +-- Mutation (state machine)
+-- FocusManager (app visibility)
+-- OnlineManager (network connectivity)
+-- NotifyManager (batched notifications)
```
