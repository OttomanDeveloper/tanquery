/// Applies [updater] to [input] if it's a function, otherwise casts it to [T].
///
/// Lets callers pass either a new value or a `T Function(T)` transformer
/// in the same parameter slot.
T functionalUpdate<T>(Object updater, T input) {
  if (updater is T Function(T)) return updater(input);
  return updater as T;
}

/// Resolves a `throwOnError` option that can be a bool or a callback.
///
/// When [throwOnError] is a function, it is called with [params] (error and
/// optionally the mutation variables). When it is a plain bool, that value
/// is returned directly.
bool shouldThrowError(Object? throwOnError, List<Object?> params) {
  if (throwOnError is bool Function(Object, Object?)) {
    return Function.apply(throwOnError, params) as bool;
  }
  if (throwOnError is bool Function(Object)) {
    return throwOnError(params.first!);
  }
  return throwOnError == true;
}
