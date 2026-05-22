import 'dart:async';
import '../core/cancelled_error.dart';
import '../core/focus_manager.dart' as fm;
import '../core/online_manager.dart' as om;
import '../models/types.dart';

class Retryer<TData> {
  final Future<TData> Function() fn;
  final int retryCount;
  final Duration Function(int failureCount) retryDelay;
  final bool Function(Object error)? retryCondition;
  final NetworkMode networkMode;
  final bool Function() canRun;
  final void Function(int failureCount, Object error)? onFail;
  final void Function()? onPause;
  final void Function()? onContinue;
  final void Function(Object error)? onCancel;
  final Future<TData>? initialPromise;

  final fm.FocusManager _focusManager;
  final om.OnlineManager _onlineManager;

  final Completer<TData> _completer = Completer<TData>();
  int _failureCount = 0;
  bool _isRetryCancelled = false;
  bool _isResolved = false;
  bool _abortSignalConsumed = false;
  Completer<void>? _pauseCompleter;

  bool get isAbortSignalConsumed => _abortSignalConsumed;

  void markAbortSignalConsumed() {
    _abortSignalConsumed = true;
  }

  Retryer({
    required this.fn,
    required this.retryCount,
    required this.retryDelay,
    this.retryCondition,
    required this.networkMode,
    required this.canRun,
    this.onFail,
    this.onPause,
    this.onContinue,
    this.onCancel,
    this.initialPromise,
    fm.FocusManager? focusManager,
    om.OnlineManager? onlineManager,
  })  : _focusManager = focusManager ?? fm.focusManager,
        _onlineManager = onlineManager ?? om.onlineManager;

  Future<TData> get promise => _completer.future;

  Future<TData> start() {
    if (_canStart()) {
      _run();
    } else {
      _pause().then((_) {
        if (!_isResolved) _run();
      });
    }
    return _completer.future;
  }

  void cancel({bool revert = false, bool silent = false}) {
    if (!_isResolved) {
      final error = CancelledError(revert: revert, silent: silent);
      _resolve(error: error);
      onCancel?.call(error);
    }
  }

  void cancelRetry() => _isRetryCancelled = true;

  void continueRetry() => _isRetryCancelled = false;

  void resume() {
    if (_pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      if (_isResolved || _canContinue()) {
        _pauseCompleter!.complete();
      }
    }
  }

  bool _canStart() => _canFetch() && canRun();

  bool _canFetch() {
    if (networkMode == NetworkMode.online) {
      return _onlineManager.isOnline();
    }
    return true;
  }

  bool _canContinue() =>
      _focusManager.isFocused() &&
      (networkMode == NetworkMode.always || _onlineManager.isOnline()) &&
      canRun();

  void _resolve({TData? data, Object? error}) {
    if (_isResolved) return;
    _isResolved = true;
    if (_pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      _pauseCompleter!.complete();
    }
    if (error != null) {
      _completer.completeError(error);
    } else {
      _completer.complete(data);
    }
  }

  Future<void> _pause() async {
    _pauseCompleter = Completer<void>();
    onPause?.call();
    await _pauseCompleter!.future;
    _pauseCompleter = null;
    if (!_isResolved) {
      onContinue?.call();
    }
  }

  Future<void> _run() async {
    if (_isResolved) return;

    try {
      final TData result;
      if (_failureCount == 0 && initialPromise != null) {
        result = await initialPromise!;
      } else {
        result = await fn();
      }
      _resolve(data: result);
    } catch (error) {
      if (_isResolved) return;

      final shouldRetry = !_isRetryCancelled &&
          _failureCount < retryCount &&
          (retryCondition?.call(error) ?? true);

      if (!shouldRetry) {
        _resolve(error: error);
        return;
      }

      _failureCount++;
      onFail?.call(_failureCount, error);

      final delay = retryDelay(_failureCount);
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }

      if (_isResolved) return;

      if (!_canContinue()) {
        await _pause();
      }

      if (_isResolved) return;
      if (_isRetryCancelled) {
        _resolve(error: error);
        return;
      }

      return _run();
    }
  }
}
