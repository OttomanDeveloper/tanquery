import 'dart:collection';
import 'dart:convert';

/// Produces a stable JSON hash from a list of key parts.
///
/// Maps are sorted by key before encoding so that `{'b': 1, 'a': 2}`
/// and `{'a': 2, 'b': 1}` produce the same hash.
String hashQueryKey(List<Object?> queryKey) {
  return jsonEncode(_prepareForHash(queryKey));
}

Object? _prepareForHash(Object? value) {
  if (value is Map) {
    final sorted = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      sorted[entry.key.toString()] = _prepareForHash(entry.value);
    }
    return sorted;
  }
  if (value is List) {
    return value.map(_prepareForHash).toList();
  }
  return value;
}
