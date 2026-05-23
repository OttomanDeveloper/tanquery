# dart_query_devtools

Visual devtools overlay for [dart_query](https://pub.dev/packages/dart_query). Inspect query cache, mutation log, and query states in real-time.

## Setup

```dart
DartQueryProvider(
  client: queryClient,
  child: DartQueryDevtools(
    enabled: kDebugMode, // only in debug builds
    child: MaterialApp(home: HomeScreen()),
  ),
);
```

## Features

**Query Inspector:**
- Live list of all cached queries with status badges (fresh/stale/fetching/paused/error/inactive)
- Data age and observer count per query
- Filter by key prefix
- Tap to view full query detail

**Query Detail:**
- Cached data formatted as JSON
- Full state: status, fetchStatus, isInvalidated, update counts
- Actions: Invalidate, Refetch, Reset, Remove
- Error display

**Mutation Log:**
- Chronological list of all mutations
- Status indicators, scope labels, timestamps
- Mutation ID tracking

**General:**
- FAB toggle -- purple to open, red to close
- Zero overhead when `enabled: false`
- Clear all caches button
- Tab switching between Queries and Mutations

## Screenshot

The overlay appears as a floating panel at the bottom of your app:

```
+----------------------------------+
| Queries (3) | Mutations (1)   [x]|
|----------------------------------|
| [Filter by key...]              |
|                                  |
| [fresh] todos        2m ago  2  |
| [stale] users        5m ago  1  |
| [fetching] posts     0s ago  3  |
|                                  |
+----------------------------------+  [FAB]
```
