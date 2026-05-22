import 'subscribable.dart';

class FocusManager extends Subscribable<void Function(bool)> {
  static final instance = FocusManager();

  bool? _focused;

  bool isFocused() => _focused ?? true;

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

final focusManager = FocusManager.instance;
