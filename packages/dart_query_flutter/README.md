# dart_query_flutter

Flutter adapter for [dart_query](https://pub.dev/packages/dart_query). Widget builders for automatic caching, stale-while-revalidate, and background refetching.

## Quick Start

```dart
import 'package:dart_query_flutter/dart_query_flutter.dart';

void main() {
  final queryClient = QueryClient();
  runApp(
    DartQueryProvider(
      client: queryClient,
      child: MaterialApp(home: HomeScreen()),
    ),
  );
}
```

## QueryBuilder

```dart
QueryBuilder<List<Todo>>(
  queryKey: QueryKey(['todos']),
  queryFn: () => api.fetchTodos(),
  staleTime: Duration(minutes: 5),
  builder: (context, state) {
    if (state.isLoading) return CircularProgressIndicator();
    if (state.isError) return Text('Error: ${state.error}');
    return ListView(
      children: state.data!.map((t) => TodoTile(t)).toList(),
    );
  },
)
```

## MutationBuilder

```dart
MutationBuilder<Todo, CreateTodoInput>(
  mutationFn: (input) => api.createTodo(input),
  onSuccess: (data, input, context) async {
    DartQuery.of(context).invalidateQueries(queryKey: QueryKey(['todos']));
  },
  builder: (context, state, mutate, mutateAsync) {
    return ElevatedButton(
      onPressed: state.isPending ? null : () => mutate(input),
      child: Text(state.isPending ? 'Saving...' : 'Add Todo'),
    );
  },
)
```

## InfiniteQueryBuilder

```dart
InfiniteQueryBuilder<List<Todo>, int>(
  queryKey: QueryKey(['todos', 'infinite']),
  queryFn: (pageParam) => api.fetchTodos(page: pageParam),
  initialPageParam: 1,
  getNextPageParam: (lastPage, allPages, lastParam, allParams) =>
    lastPage.length == 20 ? lastParam + 1 : null,
  builder: (context, state, fetchNextPage, fetchPreviousPage) {
    if (state.isLoading) return CircularProgressIndicator();
    final pages = state.data?.pages ?? [];
    return ListView.builder(
      itemCount: pages.expand((p) => p).length,
      itemBuilder: (context, i) => TodoTile(pages.expand((p) => p).elementAt(i)),
    );
  },
)
```

## QueriesBuilder (Parallel Queries)

```dart
QueriesBuilder(
  queries: [
    QueryConfig(key: QueryKey(['todos']), fn: () => api.fetchTodos()),
    QueryConfig(key: QueryKey(['user']), fn: () => api.fetchUser()),
  ],
  builder: (context, results) {
    final todos = results[0];
    final user = results[1];
    // ...
  },
)
```

## Access Client Anywhere

```dart
final client = DartQuery.of(context);
client.invalidateQueries(queryKey: QueryKey(['todos']));
client.setQueryData<String>(QueryKey(['user']), updatedUser);
```

## DevTools

See [dart_query_devtools](https://pub.dev/packages/dart_query_devtools) for a visual cache inspector overlay.

## Features

- **Zero mandatory dependencies** beyond Flutter SDK and dart_query
- **Widget builders** -- no hooks required
- **Automatic lifecycle** -- observers created/disposed with widget lifecycle
- **App focus detection** via `WidgetsBindingObserver`
- **Type-safe** -- full generic support
