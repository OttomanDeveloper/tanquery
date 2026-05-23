import 'package:meta/meta.dart';

/// Callback that removes a subscription when called.
typedef Unsubscribe = void Function();

/// Base class for objects that manage a set of listeners.
///
/// Subclasses get a subscribe/unsubscribe pattern where calling
/// [subscribe] returns an [Unsubscribe] function to remove the listener.
abstract class Subscribable<TListener extends Function> {
  /// The current set of registered listeners.
  @protected
  final Set<TListener> listeners = {};

  /// Registers [listener] and returns an [Unsubscribe] callback to remove it.
  Unsubscribe subscribe(TListener listener) {
    listeners.add(listener);
    onSubscribe();
    return () {
      listeners.remove(listener);
      onUnsubscribe();
    };
  }

  /// Whether any listeners are currently registered.
  bool get hasListeners => listeners.isNotEmpty;

  /// Called after a new listener is added. Override to react to subscriptions.
  @protected
  void onSubscribe() {}

  /// Called after a listener is removed. Override to react to unsubscriptions.
  @protected
  void onUnsubscribe() {}
}
