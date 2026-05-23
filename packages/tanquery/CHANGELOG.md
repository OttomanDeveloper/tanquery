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
