import 'dart:async';

class NotifyManager {
  List<void Function()> _queue = [];
  int _transactions = 0;
  void Function(void Function()) _scheduleFn = scheduleMicrotask;
  void Function(void Function()) _notifyFn = (cb) => cb();
  void Function(void Function()) _batchNotifyFn = (cb) => cb();

  T batch<T>(T Function() callback) {
    _transactions++;
    try {
      return callback();
    } finally {
      _transactions--;
      if (_transactions == 0) _flush();
    }
  }

  void schedule(void Function() callback) {
    if (_transactions > 0) {
      _queue.add(callback);
    } else {
      _scheduleFn(() => _notifyFn(callback));
    }
  }

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

  void setScheduler(void Function(void Function()) fn) => _scheduleFn = fn;
  void setNotifyFunction(void Function(void Function()) fn) => _notifyFn = fn;
  void setBatchNotifyFunction(void Function(void Function()) fn) =>
      _batchNotifyFn = fn;
}

final notifyManager = NotifyManager();
