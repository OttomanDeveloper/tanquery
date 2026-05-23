# tanquery

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Dart 3](https://img.shields.io/badge/Dart-3.5+-0175C2.svg)](https://dart.dev)

TanStack Query for Dart/Flutter. Stop writing fetch-cache-retry-loading-error boilerplate. Get automatic caching, stale-while-revalidate, background refetching, mutations with optimistic updates, infinite queries, and visual devtools.

## Packages

| Package | Description | Version |
|---|---|---|
| [tanquery](packages/tanquery/) | Pure Dart core, no Flutter dependency | [![pub](https://img.shields.io/pub/v/tanquery.svg)](https://pub.dev/packages/tanquery) |
| [tanquery_flutter](packages/tanquery_flutter/) | Flutter widget builders | [![pub](https://img.shields.io/pub/v/tanquery_flutter.svg)](https://pub.dev/packages/tanquery_flutter) |
| [tanquery_devtools](packages/tanquery_devtools/) | Visual cache inspector overlay | [![pub](https://img.shields.io/pub/v/tanquery_devtools.svg)](https://pub.dev/packages/tanquery_devtools) |

## Before and after

Without tanquery, every screen that fetches data looks like this:

```dart
class _TodoScreenState extends State<TodoScreen> {
  bool _isLoading = true;
  Object? _error;
  List<Todo>? _data;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _isLoading = true; });
    try {
      _data = await api.fetchTodos();
    } catch (e) { _error = e; }
    setState(() { _isLoading = false; });
  }

  @override Widget build(BuildContext context) {
    if (_isLoading) return CircularProgressIndicator();
    if (_error != null) return Text('Error');
    return ListView(children: _data!.map(TodoTile.new).toList());
  }
}
```

With tanquery:

```dart
QueryBuilder<List<Todo>>(
  queryKey: QueryKey(['todos']),
  queryFn: () => api.fetchTodos(),
  builder: (context, state) {
    if (state.isLoading) return CircularProgressIndicator();
    if (state.isError) return Text('Error: ${state.error}');
    return ListView(children: state.data!.map(TodoTile.new).toList());
  },
)
```

You also get caching, retries, background refetch on focus, request deduplication, hierarchical invalidation, and garbage collection. Automatically.

## Quick start

### 1. Install

```yaml
# pubspec.yaml
dependencies:
  tanquery_flutter: ^0.7.1
```

For pure Dart projects (no Flutter):
```yaml
dependencies:
  tanquery: ^0.7.1
```

### 2. Create a client and wrap your app

```dart
import 'package:tanquery_flutter/tanquery_flutter.dart';

final queryClient = QueryClient();

void main() => runApp(
  DartQueryProvider(
    client: queryClient,
    child: MaterialApp(home: HomeScreen()),
  ),
);
```

### 3. Fetch data

```dart
QueryBuilder<List<Todo>>(
  queryKey: QueryKey(['todos']),
  queryFn: () async {
    final response = await http.get(Uri.parse('https://api.example.com/todos'));
    return (jsonDecode(response.body) as List).map(Todo.fromJson).toList();
  },
  builder: (context, state) {
    if (state.isLoading) return const CircularProgressIndicator();
    if (state.isError) return Text('Error: ${state.error}');
    return ListView.builder(
      itemCount: state.data!.length,
      itemBuilder: (_, i) => Text(state.data![i].title),
    );
  },
)
```

### 4. Mutate data

```dart
MutationBuilder<Todo, String>(
  mutationFn: (title) async {
    final response = await http.post(
      Uri.parse('https://api.example.com/todos'),
      body: jsonEncode({'title': title}),
    );
    return Todo.fromJson(jsonDecode(response.body));
  },
  onSuccess: (data, variables, context) async {
    // Refetch the todo list after creating a new one
    await DartQuery.of(context!).invalidateQueries(
      queryKey: QueryKey(['todos']),
    );
  },
  builder: (context, state, mutate, mutateAsync) {
    return ElevatedButton(
      onPressed: state.isPending ? null : () => mutate('Buy milk'),
      child: state.isPending ? const CircularProgressIndicator() : const Text('Add Todo'),
    );
  },
)
```

### 5. Infinite scroll

```dart
InfiniteQueryBuilder<List<Post>, int>(
  queryKey: QueryKey(['posts']),
  queryFn: (page) async {
    final response = await http.get(
      Uri.parse('https://api.example.com/posts?page=$page&limit=20'),
    );
    return (jsonDecode(response.body) as List).map(Post.fromJson).toList();
  },
  initialPageParam: 1,
  getNextPageParam: (lastPage, allPages, lastParam, allParams) {
    return lastPage.isEmpty ? null : lastParam + 1;
  },
  builder: (context, state, fetchNextPage, fetchPreviousPage) {
    if (state.isLoading) return const CircularProgressIndicator();
    final allPosts = state.data!.pages.expand((page) => page).toList();
    return ListView.builder(
      itemCount: allPosts.length + 1,
      itemBuilder: (_, i) {
        if (i == allPosts.length) {
          return TextButton(onPressed: fetchNextPage, child: const Text('Load more'));
        }
        return Text(allPosts[i].title);
      },
    );
  },
)
```

## Features

- **Automatic caching** -- fetched data is cached and reused across the widget tree
- **Stale-while-revalidate** -- show cached data instantly while silently refetching in the background
- **Background refetch** -- on app focus, network reconnect, and configurable intervals
- **Exponential retry** -- 1s, 2s, 4s, 8s, 16s, 30s cap, configurable per query
- **Request deduplication** -- 10 widgets requesting the same data produce 1 network call
- **Hierarchical invalidation** -- invalidate `['todos']` also clears `['todos', 1]`, `['todos', 2]`, etc.
- **Mutations** -- create/update/delete with callbacks for optimistic updates and rollback
- **Infinite scroll** -- built-in pagination with `fetchNextPage` and `fetchPreviousPage`
- **Streaming** -- wrap WebSocket, SSE, or LLM streams as queryable data sources
- **Cache persistence** -- dehydrate/hydrate the cache for offline support
- **Visual devtools** -- inspect cache state, filter by status, invalidate/refetch/remove from a floating overlay
- **Pure Dart core** -- the core package works without Flutter (Shelf servers, CLI tools, Dart Frog)
- **Two-axis state model** -- QueryStatus (pending/success/error) + FetchStatus (fetching/paused/idle) give you precise control over loading states

## Architecture

This is a faithful Dart port of [TanStack Query](https://tanstack.com/query), built by analyzing all 8,698 lines of the original TypeScript source. The architecture maps 1:1:

| TanStack (TS) | tanquery (Dart) |
|---|---|
| `QueryClient` | `QueryClient` |
| `QueryCache` | `QueryCache` |
| `Query` | `Query<TData>` |
| `QueryObserver` | `QueryObserver<TData>` |
| `MutationCache` | `MutationCache` |
| `Mutation` | `Mutation<TData, TVariables>` |
| `MutationObserver` | `MutationObserver<TData, TVariables>` |
| `Retryer` | `Retryer<T>` (internal) |
| `useQuery()` hook | `QueryBuilder<T>` widget |
| `useMutation()` hook | `MutationBuilder<TData, TVariables>` widget |
| `useInfiniteQuery()` hook | `InfiniteQueryBuilder<TPage, TParam>` widget |
| React DevTools panel | `DartQueryDevtools` overlay widget |

## Configuration

### QueryClient defaults

```dart
final client = QueryClient(
  defaultStaleTime: Duration.zero,          // how long data stays fresh
  defaultGcTime: const Duration(minutes: 5), // how long unused data stays in cache
  defaultRetryCount: 3,                     // retries on failure
  defaultNetworkMode: NetworkMode.online,   // when queries can fetch
);
```

### Per-query options

```dart
QueryBuilder<User>(
  queryKey: QueryKey(['user', userId]),
  queryFn: () => api.fetchUser(userId),
  staleTime: const Duration(minutes: 10),  // fresh for 10 minutes
  gcTime: const Duration(hours: 1),        // keep in cache for 1 hour
  enabled: userId != null,                 // conditional fetching
  refetchInterval: const Duration(seconds: 30), // poll every 30s
  retryCount: 5,                           // retry up to 5 times
  networkMode: NetworkMode.offlineFirst,   // try cache first
  select: (user) => user.name,            // transform before rendering
  builder: (context, state) => Text(state.data ?? 'Loading...'),
)
```

### Imperative API

```dart
final client = DartQuery.of(context);

// Read cached data (no fetch)
final todos = client.getQueryData<List<Todo>>(QueryKey(['todos']));

// Write to cache directly
client.setQueryData<List<Todo>>(QueryKey(['todos']), (old) => [...old!, newTodo]);

// Fetch (respects staleness)
final data = await client.fetchQuery(
  queryKey: QueryKey(['user', 1]),
  queryFn: () => api.fetchUser(1),
);

// Prefetch (fire and forget, swallows errors)
await client.prefetchQuery(
  queryKey: QueryKey(['user', 2]),
  queryFn: () => api.fetchUser(2),
);

// Invalidate and refetch
await client.invalidateQueries(queryKey: QueryKey(['todos']));

// Cancel in-flight queries
await client.cancelQueries(queryKey: QueryKey(['todos']));

// Remove from cache entirely
client.removeQueries(queryKey: QueryKey(['todos']));

// Reset to initial state and refetch
await client.resetQueries(queryKey: QueryKey(['todos']));
```

## Devtools

Add the devtools overlay to see all cached queries and mutations at runtime:

```dart
MaterialApp(
  builder: (context, child) => DartQueryDevtools(
    enabled: kDebugMode, // disable in release builds
    child: child!,
  ),
)
```

The overlay shows:
- All cached queries with color-coded status badges (fresh/stale/fetching/paused/error/inactive)
- Data age and observer count per query
- Full cached data formatted as JSON
- Action buttons: invalidate, refetch, reset, remove
- Mutation log with status history
- Text and status filters

## Streaming

Wrap any `Stream` as a query:

```dart
QueryBuilder<String>(
  queryKey: QueryKey(['chat', roomId]),
  queryFn: streamedQuery<String, String>(
    streamFn: () => websocket.messages(roomId),
    reducer: (accumulated, chunk) => accumulated + chunk,
    initialValue: '',
    refetchMode: RefetchMode.append,
    getCurrentData: () => client.getQueryData(QueryKey(['chat', roomId])),
  ),
  builder: (context, state) => Text(state.data ?? ''),
)
```

Three refetch modes:
- `reset` -- start over from `initialValue`
- `append` -- continue from existing cached data
- `replace` -- start from `initialValue`, only update cache when the stream closes

## Cache persistence

Save and restore cache across app restarts:

```dart
// Save
final dehydrated = dehydrate(client);
final json = jsonEncode(dehydrated.toJson());
await prefs.setString('query_cache', json);

// Restore
final json = prefs.getString('query_cache');
if (json != null) {
  final state = DehydratedState.fromJson(jsonDecode(json));
  hydrate(client, state);
}
```

## Parallel queries

Fetch multiple queries at once with `QueriesBuilder`:

```dart
QueriesBuilder(
  queries: [
    QueryConfig(key: QueryKey(['users']), fn: () => api.fetchUsers()),
    QueryConfig(key: QueryKey(['posts']), fn: () => api.fetchPosts()),
    QueryConfig(key: QueryKey(['comments']), fn: () => api.fetchComments()),
  ],
  builder: (context, results) {
    if (results.any((r) => r.isLoading)) return const CircularProgressIndicator();
    final users = results[0].data as List<User>;
    final posts = results[1].data as List<Post>;
    return Column(children: [
      Text('${users.length} users'),
      Text('${posts.length} posts'),
    ]);
  },
)
```

## Pure Dart usage

The core `tanquery` package works without Flutter. Use it in server apps, CLI tools, or anywhere Dart runs:

```dart
import 'package:tanquery/tanquery.dart';

void main() async {
  final client = QueryClient();
  client.mount();

  final todos = await client.fetchQuery(
    queryKey: QueryKey(['todos']),
    queryFn: () async {
      // your fetch logic
      return ['Buy milk', 'Walk the dog'];
    },
  );

  print(todos); // ['Buy milk', 'Walk the dog']

  // Second call returns cached data instantly
  final cached = await client.fetchQuery(
    queryKey: QueryKey(['todos']),
    queryFn: () => throw 'should not be called',
    staleTime: const Duration(minutes: 5),
  );

  print(cached); // ['Buy milk', 'Walk the dog']

  client.unmount();
}
```

## Requirements

- Dart SDK >= 3.5.0
- Flutter >= 3.0.0 (for tanquery_flutter and tanquery_devtools)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup instructions and guidelines.

## License

MIT. See [LICENSE](LICENSE) for details.

Copyright (c) 2026 Muhammad Usman (OttomanDeveloper)
