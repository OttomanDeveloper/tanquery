import 'subscribable.dart';

/// Tracks whether the application has focus and notifies listeners on changes.
///
/// Queries can use focus state to refetch data when the app regains focus.
class FocusManager extends Subscribable<void Function(bool)> {
  /// Shared singleton instance.
  static final instance = FocusManager();

  bool? _focused;

  /// Returns true if the app is focused. Defaults to true when unset.
  bool isFocused() => _focused ?? true;

  /// Sets the focus state and notifies listeners if it changed.
  void setFocused(bool focused) {
    final changed = _focused != focused;
    _focused = focused;
    if (changed) {
      for (final listener in listeners) {
        listener(focused);
      }
    }
  }
}

/// Global [FocusManager] instance.
final focusManager = FocusManager.instance;
