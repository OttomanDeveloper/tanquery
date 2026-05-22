import '../utils/hash_key.dart';

class QueryKey {
  final List<Object?> parts;
  late final String queryHash;

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
