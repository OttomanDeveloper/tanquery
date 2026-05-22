import 'subscribable.dart';

class OnlineManager extends Subscribable<void Function(bool)> {
  static final instance = OnlineManager();

  bool _online = true;

  bool isOnline() => _online;

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

final onlineManager = OnlineManager.instance;
