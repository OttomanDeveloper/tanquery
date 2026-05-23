import 'subscribable.dart';

/// Tracks network connectivity and notifies listeners on changes.
///
/// Queries can use online state to pause fetches when offline and
/// resume them when connectivity returns.
class OnlineManager extends Subscribable<void Function(bool)> {
  /// Shared singleton instance.
  static final instance = OnlineManager();

  bool _online = true;

  /// Returns true if the app is online.
  bool isOnline() => _online;

  /// Sets the online state and notifies listeners if it changed.
  void setOnline(bool online) {
    final changed = _online != online;
    _online = online;
    if (changed) {
      for (final listener in listeners) {
        listener(online);
      }
    }
  }
}

/// Global [OnlineManager] instance.
final onlineManager = OnlineManager.instance;
