/// Appends [item] to the end of [items], dropping the oldest entry if
/// the result exceeds [max]. Pass `max: 0` (the default) for no limit.
List<T> addToEnd<T>(List<T> items, T item, {int max = 0}) {
  final result = [...items, item];
  if (max > 0 && result.length > max) return result.sublist(1);
  return result;
}

/// Prepends [item] to the start of [items], dropping the last entry if
/// the result exceeds [max]. Pass `max: 0` (the default) for no limit.
List<T> addToStart<T>(List<T> items, T item, {int max = 0}) {
  final result = [item, ...items];
  if (max > 0 && result.length > max) return result.sublist(0, result.length - 1);
  return result;
}
