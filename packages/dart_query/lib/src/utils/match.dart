bool partialMatchKey(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a == b) return true;
  if (a == null || b == null) return false;

  if (a is Map && b is Map) {
    return b.keys.every(
      (key) => a.containsKey(key) && partialMatchKey(a[key], b[key]),
    );
  }

  if (a is List && b is List) {
    if (b.length > a.length) return false;
    for (var i = 0; i < b.length; i++) {
      if (!partialMatchKey(a[i], b[i])) return false;
    }
    return true;
  }

  return false;
}
