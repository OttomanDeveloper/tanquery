import 'dart:collection';
import 'dart:convert';

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
