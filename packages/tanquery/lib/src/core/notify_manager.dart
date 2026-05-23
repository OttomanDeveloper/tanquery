import 'dart:async';

/// Batches and schedules notification callbacks.
///
/// During a [batch] call, scheduled callbacks are queued and flushed together
/// once the batch completes. Outside a batch, callbacks are dispatched via
/// the configured scheduler (microtask by default).
class NotifyManager {
  List<void Function()> _queue = [];
  int _transactions = 0;
  void Function(void Function()) _scheduleFn = scheduleMicrotask;
  void Function(void Function()) _notifyFn = (cb) => cb();
  void Function(void Function()) _batchNotifyFn = (cb) => cb();

  /// Runs [callback] inside a batch transaction.
  ///
  /// Any calls to [schedule] within [callback] are queued and flushed
  /// after the callback returns.
  T batch<T>(T Function() callback) {
    _transactions++;
    try {
      return callback();
    } finally {
      _transactions--;
      if (_transactions == 0) _flush();
    }
  }

  /// Schedules [callback] for execution.
  ///
  /// If inside a [batch], the callback is queued. Otherwise it runs
  /// through the scheduler immediately.
  void schedule(void Function() callback) {
    if (_transactions > 0) {
      _queue.add(callback);
    } else {
      _scheduleFn(() => _notifyFn(callback));
    }
  }

  /// Wraps [callback] so each invocation is routed through [schedule].
  void Function(T) batchCalls<T>(void Function(T) callback) {
    return (T arg) {
      schedule(() => callback(arg));
    };
  }

  void _flush() {
    final originalQueue = _queue;
    _queue = [];
    if (originalQueue.isNotEmpty) {
      _batchNotifyFn(() {
        for (final callback in originalQueue) {
          _notifyFn(callback);
        }
      });
    }
  }

  /// Replaces the scheduling function used to dispatch callbacks.
  ///
  /// Defaults to [scheduleMicrotask].
  void setScheduler(void Function(void Function()) fn) => _scheduleFn = fn;

  /// Replaces the function that wraps each notification callback.
  void setNotifyFunction(void Function(void Function()) fn) => _notifyFn = fn;

  /// Replaces the function that wraps batch flushes.
  void setBatchNotifyFunction(void Function(void Function()) fn) =>
      _batchNotifyFn = fn;
}

/// Global [NotifyManager] instance used by the query client.
final notifyManager = NotifyManager();
