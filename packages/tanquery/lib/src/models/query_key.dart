import '../utils/hash_key.dart';

/// Identifies a query in the cache.
///
/// Built from a list of [parts] that are hashed into a single [queryHash]
/// string. Two keys with the same parts produce the same hash and are
/// considered equal.
final class QueryKey {
  /// The segments that make up this key.
  final List<Object?> parts;

  /// Deterministic hash computed from [parts], used for equality and lookups.
  final String queryHash;

  /// Creates a query key from the given [parts].
  QueryKey(this.parts) : queryHash = hashQueryKey(parts);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueryKey && queryHash == other.queryHash);

  @override
  int get hashCode => queryHash.hashCode;

  @override
  String toString() => 'QueryKey($parts)';
}
