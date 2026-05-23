## 0.7.1

### Documentation
- Added dartdoc comments to all public APIs: classes, methods, fields, typedefs, enums, enum values, constructors, and top-level functions.

## 0.7.0

### Bug Fixes
- **Structural sharing cast failure fixed** -- `replaceEqualDeep` returned `List<Object?>` instead of `List<T>` when queries were accessed through untyped `Query` references (e.g., from `invalidateQueries` → `refetchQueries` → `findAll`). Now safely checks `shared is TData` before casting, falling back to original typed data.
- **`catchError` type mismatch fixed** -- Replaced all `catchError((_) => null)` and `.ignore()` with `async/try/catch` or `.then((_) {}, onError: (_) {})` patterns. Prevents "The error handler of Future.catchError must return a value of the future's type" runtime error.
- **`refetchQueries` no longer leaks futures** -- Uses `async/try/catch` instead of chained `.then().catchError()`.

## 0.6.0

### Bug Fixes
- **`setQueryData` with function updater no longer crashes when no prior data exists** -- Now accepts `TData? Function(TData?)` for nullable-safe updates instead of force-casting to non-nullable.
- **Custom `focusManager`/`onlineManager` on QueryClient now propagated to all queries** -- Previously only affected MutationCache and mount lifecycle. Now QueryCache passes them through to every Query created via `build()`.
- **`MutationObserver` per-call callbacks no longer silently skipped** -- `onSuccess`/`onError`/`onSettled` from `mutate()` args now fire regardless of subscriber count. Previously gated by `hasListeners`.
- **`Query.reset()` now notifies observers and reschedules GC** -- Previously set state directly (bypassing `_dispatch`), causing memory leaks (no GC timer) and devtools missing the reset.

## 0.5.0

### Improvements
- **Removed `Retryer.markAbortSignalConsumed()`** -- Dart has no AbortSignal equivalent. The mechanism was scaffolding with no call path. `removeObserver()` simplified to always use `cancelRetry()`.
- **Removed `QueryObserver._onlineManager`** -- TanStack's QueryObserver has zero onlineManager reference. All online-awareness correctly delegated to Query/Retryer layers.
- **Wired DevTools status filter** -- Added clickable status filter chips (all/fresh/stale/fetching/paused/error/inactive) to the query list panel. `QueryListView` now filters by status.

## 0.4.0

### Bug Fixes
- **Error reducer no longer sets `isInvalidated: true`** -- Matches TanStack Query behavior. Previously, errored queries were always marked invalidated, causing aggressive refetch loops on focus/reconnect for queries that consistently fail. Now the `isInvalidated` flag is preserved through errors.
- **`invalidateQueries(refetchType: QueryTypeFilter.all)` now correctly refetches all queries** -- Previously dropped the `refetchType` parameter and defaulted to `active` only.
- **`refetchQueries()` no longer leaks futures for paused queries** -- Now checks paused state before initiating fetch instead of after.

### Improvements
- **`Query._abortSignalConsumed` properly wired to `Retryer.isAbortSignalConsumed`** -- `removeObserver()` now correctly chooses between `cancel(revert: true)` and `cancelRetry()` based on whether the abort signal was consumed by the query function.
- **`isDisabled()` simplified** -- Removed tautological branch that always returned false.
- **Unsafe null assertions removed** -- `QueryCache` config callbacks (`onSuccess`, `onError`) now accept nullable data/error, preventing runtime crashes with nullable `TData` types.

### Dead Code Removed
- Removed `isStatic()` method (always returned false, never called)
- Removed `setCacheNotify()` method (never called externally)
- Removed `FetchDirection` enum (unused across entire monorepo)
- Removed `EventType.observerResultsUpdated` and `EventType.observerOptionsUpdated` (never emitted)
- Removed `StaleTime.zero` and `StaleTime.isZero` (never used)
- Removed unnecessary `late` keyword on `QueryKey.queryHash`

## 0.3.0

### Improvements
- Renamed packages from `dart_query` to `tanquery` for pub.dev compatibility

## 0.2.0

### Improvements
- Updated repository URL to https://github.com/OttomanDeveloper/tanquery
- Comprehensive beginner-friendly README with progressive disclosure
- Before/after comparisons, API reference tables, architecture diagram

## 0.1.0

### Initial Release
- QueryClient with mount/unmount lifecycle and reference counting
- QueryCache with build-or-get pattern, partial key matching, garbage collection
- Query state machine with 8-action reducer and two-axis state model (QueryStatus + FetchStatus)
- QueryObserver with select (3-level memoization), placeholderData, stale timer, refetch interval
- Retryer with exponential backoff (1s-30s cap), pause/continue/cancel, 3 network modes
- MutationCache with scoped sequential execution via canRun/runNext
- Mutation with exact TanStack callback ordering (cache-level before instance-level)
- MutationObserver with mutate (fire-and-forget) and mutateAsync (awaitable)
- Hydration/dehydration for cache persistence with error redaction
- StreamedQuery for real-time data (WebSocket, SSE, LLM streaming) with 3 refetch modes
- Structural sharing via replaceEqualDeep (depth limit 500)
- InMemoryQueryStorage with copy-on-read/write
- skipToken for type-safe conditional queries
- StaleTime.static_ for never-stale data
- 310 tests
