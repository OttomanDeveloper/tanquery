class _SkipToken {
  const _SkipToken();
}

const skipToken = _SkipToken();

bool isSkipToken(Object? value) => value is _SkipToken;

T? keepPreviousData<T>(T? previousData, Object? previousQuery) => previousData;
