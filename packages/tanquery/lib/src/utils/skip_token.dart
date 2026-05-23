class _SkipToken {
  const _SkipToken();
}

/// Sentinel value that signals a query should be skipped (not executed).
///
/// Pass this as the query function to disable a query while keeping it
/// registered in the cache. Commonly used for dependent queries that
/// should wait until their prerequisites are met.
const skipToken = _SkipToken();

/// Returns true if [value] is the [skipToken] sentinel.
bool isSkipToken(Object? value) => value is _SkipToken;

/// Placeholder select callback that returns previous data unchanged.
///
/// Use as a `placeholderData` value to keep showing the last successful
/// result while a new query key is loading.
T? keepPreviousData<T>(T? previousData, Object? previousQuery) => previousData;
