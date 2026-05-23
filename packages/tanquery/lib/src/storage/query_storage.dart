/// Persists query cache data across sessions.
///
/// Implement this to store dehydrated query state in SharedPreferences,
/// Hive, SQLite, or any other storage backend.
abstract class QueryStorage {
  /// Writes [data] under [key], replacing any existing entry.
  Future<void> save(String key, Map<String, dynamic> data);

  /// Returns the data previously stored under [key], or null if absent.
  Future<Map<String, dynamic>?> load(String key);

  /// Deletes the entry for [key]. No-op if [key] does not exist.
  Future<void> remove(String key);

  /// Removes all stored entries.
  Future<void> clear();
}
