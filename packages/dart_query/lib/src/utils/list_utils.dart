List<T> addToEnd<T>(List<T> items, T item, {int max = 0}) {
  final result = [...items, item];
  if (max > 0 && result.length > max) return result.sublist(1);
  return result;
}

List<T> addToStart<T>(List<T> items, T item, {int max = 0}) {
  final result = [item, ...items];
  if (max > 0 && result.length > max) return result.sublist(0, result.length - 1);
  return result;
}
