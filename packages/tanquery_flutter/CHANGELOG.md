## 0.8.0

### Type Safety
- Added `final` class modifier to `QueryConfig` (data class, not meant to be extended).
- Added `abstract final` class modifier to `DartQuery` (utility class with static method only, not meant to be instantiated or extended).
- Updated dependency to `tanquery: ^0.8.0`.

## 0.7.1

### Documentation
- Added dartdoc comments to all public APIs: widgets, typedefs, widget properties, and constructors. Includes usage examples for QueryBuilder, MutationBuilder, InfiniteQueryBuilder, and QueriesBuilder.

## 0.7.0

### Bug Fixes
- **InfiniteQueryBuilder `catchError` type mismatch fixed** -- Replaced `.catchError((_) {})` with `.then((_) {}, onError: (_) {})` to prevent Future type mismatch errors on page fetch failures.

## 0.6.0

### Bug Fixes
- **InfiniteQueryBuilder: `_isFetchingPage` reset on widget reconfiguration** -- Previously stuck at `true` after config change (e.g., queryKey change), permanently blocking `fetchNextPage`/`fetchPreviousPage`.

## 0.5.0

### Improvements
- No functional changes. Version bump for dependency compatibility with tanquery 0.5.0.

## 0.4.0

### Bug Fixes
- **InfiniteQueryBuilder: observer now properly destroyed on dispose** -- Previously leaked timers and observer registrations, potentially causing `setState` on disposed widgets.
- **InfiniteQueryBuilder: race condition guard** -- Added `_isFetchingPage` flag to prevent concurrent `fetchNextPage`/`fetchPreviousPage` calls from corrupting page data.
- **InfiniteQueryBuilder: error handling on page fetch** -- `fetchNextPage`/`fetchPreviousPage` now catch and swallow errors instead of leaving unhandled futures.
- **InfiniteQueryBuilder: mounted check** -- Both fetch methods now check `mounted` before accessing `context` or calling `setState`.

### Improvements
- **InfiniteQueryBuilder: `maxPages` now enforced** -- Previously accepted but ignored. Now trims pages from the opposite end when limit is exceeded.
- **InfiniteQueryBuilder: `didUpdateWidget` detects all config changes** -- Now detects changes to `queryFn`, `initialPageParam`, `getNextPageParam`, `getPreviousPageParam`, `gcTime`, `maxPages` in addition to `queryKey`, `staleTime`, `enabled`, `retryCount`.
- **QueryBuilder: `didUpdateWidget` detects all config changes** -- Now detects changes to `queryFn`, `select`, `placeholderData`, `placeholderDataFn`, `retryCount`, `networkMode`, `gcTime` in addition to the original 4 properties.
- **QueriesBuilder: `_queriesChanged` detects `staleTime` and `enabled` changes** -- Previously only checked query keys.

## 0.3.0

### Improvements
- Renamed packages from `dart_query_flutter` to `tanquery_flutter` for pub.dev compatibility

## 0.2.0

### Improvements
- Updated repository URL to https://github.com/OttomanDeveloper/tanquery
- Comprehensive beginner-friendly README with before/after examples
- Common patterns section: conditional fetching, polling, pull-to-refresh

## 0.1.0

### Initial Release
- DartQueryProvider with InheritedWidget + lifecycle wiring
- Automatic `QueryClient.mount()`/`unmount()` lifecycle management
- App focus detection via `WidgetsBindingObserver` wired to `FocusManager`
- `DartQuery.of(context)` for client access with descriptive error message
- QueryBuilder widget with full query option support
- MutationBuilder widget with `mutate` (fire-and-forget) and `mutateAsync` (awaitable)
- InfiniteQueryBuilder widget with `fetchNextPage`/`fetchPreviousPage`
- QueriesBuilder for parallel query coordination
- All widgets use `didChangeDependencies` (not `initState`) for proper InheritedWidget access
- Null-safe observer guards in `build()` methods
- Barrel export re-exports `tanquery` core (hides `FocusManager` to avoid Flutter collision)
- 5 widget tests
