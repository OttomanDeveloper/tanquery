Object? replaceEqualDeep(Object? a, Object? b, {int depth = 0}) {
  if (identical(a, b)) return a;
  if (depth > 500) return b;

  if (a is List && b is List) {
    if (a.length != b.length) {
      return List.generate(b.length, (i) {
        return i < a.length
            ? replaceEqualDeep(a[i], b[i], depth: depth + 1)
            : b[i];
      });
    }
    var allEqual = true;
    final result = List.generate(b.length, (i) {
      final item = replaceEqualDeep(a[i], b[i], depth: depth + 1);
      if (!identical(item, a[i])) allEqual = false;
      return item;
    });
    return allEqual ? a : result;
  }

  if (a is Map && b is Map) {
    final bKeys = b.keys.toList();
    if (a.length != b.length) {
      return {
        for (final key in bKeys)
          key: a.containsKey(key)
              ? replaceEqualDeep(a[key], b[key], depth: depth + 1)
              : b[key],
      };
    }
    var allEqual = true;
    final result = <Object?, Object?>{};
    for (final key in bKeys) {
      if (!a.containsKey(key)) {
        allEqual = false;
        result[key] = b[key];
      } else {
        final item = replaceEqualDeep(a[key], b[key], depth: depth + 1);
        if (!identical(item, a[key])) allEqual = false;
        result[key] = item;
      }
    }
    return allEqual ? a : result;
  }

  if (a == b) return a;
  return b;
}
