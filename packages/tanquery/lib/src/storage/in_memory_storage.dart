import 'query_storage.dart';

/// Non-persistent [QueryStorage] backed by a plain [Map].
///
/// Useful for tests and as a default when no durable storage is configured.
/// All data is lost when the process exits.
final class InMemoryQueryStorage implements QueryStorage {
  final Map<String, Map<String, dynamic>> _store = {};

  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    _store[key] = Map.from(data);
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    final data = _store[key];
    return data != null ? Map.from(data) : null;
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  /// Number of entries currently held in memory.
  int get length => _store.length;
}
