# dart_query

TanStack Query for Dart/Flutter. Automatic caching, stale-while-revalidate, background refetching, mutations with optimistic updates, infinite queries, and visual devtools.

## Packages

| Package | Description | pub.dev |
|---|---|---|
| [dart_query](packages/dart_query/) | Pure Dart core -- zero Flutter dependency | [![pub](https://img.shields.io/pub/v/dart_query.svg)](https://pub.dev/packages/dart_query) |
| [dart_query_flutter](packages/dart_query_flutter/) | Flutter widget builders (QueryBuilder, MutationBuilder) | [![pub](https://img.shields.io/pub/v/dart_query_flutter.svg)](https://pub.dev/packages/dart_query_flutter) |
| [dart_query_devtools](packages/dart_query_devtools/) | Visual cache inspector overlay | [![pub](https://img.shields.io/pub/v/dart_query_devtools.svg)](https://pub.dev/packages/dart_query_devtools) |

## Quick Start

```dart
import 'package:dart_query_flutter/dart_query_flutter.dart';

void main() {
  runApp(
    DartQueryProvider(
      client: QueryClient(),
      child: MaterialApp(home: HomeScreen()),
    ),
  );
}

// In any widget:
QueryBuilder<List<Todo>>(
  queryKey: QueryKey(['todos']),
  queryFn: () => api.fetchTodos(),
  builder: (context, state) {
    if (state.isLoading) return CircularProgressIndicator();
    return ListView(children: state.data!.map(TodoTile.new).toList());
  },
)
```

## Architecture

Faithfully follows [TanStack Query](https://tanstack.com/query)'s proven internal architecture with a pure Dart core and thin Flutter adapter.

## License

MIT
