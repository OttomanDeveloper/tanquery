## 0.8.0

### Improvements
- Updated dependencies to `tanquery: ^0.8.0` and `tanquery_flutter: ^0.8.0`.

## 0.7.1

### Documentation
- Added dartdoc comments to DartQueryDevtools widget and its public properties, with MaterialApp.builder usage example.

## 0.7.0

### Bug Fixes
- **Overlay widget error fixed** -- Wrapped devtools panel in its own `Overlay` widget. Fixes "No Overlay widget found" crash when placed inside `MaterialApp.builder` (above Navigator).
- **Refetch action error fixed** -- Replaced `.catchError` / `.ignore()` with safe `.then((_) {}, onError: (_) {})` pattern.

## 0.6.0

### Improvements
- No functional changes. Version bump for dependency compatibility with tanquery 0.6.0.

## 0.5.0

### Features
- **Status filter chips** -- Added clickable status filter bar (all/fresh/stale/fetching/paused/error/inactive) to the query list panel. Matches TanStack DevTools behavior.

## 0.4.0

### Bug Fixes
- **Filter now searches query key parts instead of hash** -- Previously searched the computed `queryHash` string, which made the filter useless for human-readable search. Now searches `queryKey.parts.join(', ')` matching what users see in the list.

### Dead Code Removed
- `statusFilter` parameter on `QueryListView` was accepted but never read in the build method (no functional change since no caller passed it)

## 0.3.0

### Improvements
- Renamed packages from `dart_query_devtools` to `tanquery_devtools` for pub.dev compatibility

## 0.2.0

### Improvements
- Updated repository URL to https://github.com/OttomanDeveloper/tanquery
- Comprehensive README with debugging scenarios and status badge reference

## 0.1.0

### Initial Release
- `DartQueryDevtools` overlay widget with `enabled` flag (zero overhead when disabled)
- Purple FAB toggle -- tap to open/close the inspector panel
- **Query List Tab:**
  - Live list of all cached queries with color-coded status badges
  - Status types: fresh (green), stale (orange), fetching (blue), paused (purple), error (red), inactive (grey)
  - Data age display ("2m ago")
  - Observer count per query
  - Text filter by query key
- **Query Detail View:**
  - Full cached data formatted as JSON
  - Complete state display: status, fetchStatus, isInvalidated, dataUpdateCount, errorUpdateCount, failureCount, dataUpdatedAt
  - Actions: Invalidate, Refetch, Reset, Remove
  - Error display with stack trace
- **Mutation Log Tab:**
  - Chronological list of all mutations (newest first)
  - Color-coded status dots (idle/pending/success/error)
  - Mutation ID, scope label, timestamp
- **General:**
  - Tab switching between Queries and Mutations
  - "Clear all" button to wipe both caches
  - Live updates via QueryCache and MutationCache subscriptions
- 4 widget tests
