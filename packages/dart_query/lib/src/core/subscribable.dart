import 'package:meta/meta.dart';

typedef Unsubscribe = void Function();

abstract class Subscribable<TListener extends Function> {
  @protected
  final Set<TListener> listeners = {};

  Unsubscribe subscribe(TListener listener) {
    listeners.add(listener);
    onSubscribe();
    return () {
      listeners.remove(listener);
      onUnsubscribe();
    };
  }

  bool get hasListeners => listeners.isNotEmpty;

  @protected
  void onSubscribe() {}

  @protected
  void onUnsubscribe() {}
}
