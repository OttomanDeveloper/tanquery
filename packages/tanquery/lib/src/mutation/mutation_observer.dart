import '../core/notify_manager.dart' as nm;
import '../core/subscribable.dart';
import '../models/mutation_state.dart';
import '../models/types.dart';
import 'mutation.dart';
import 'mutation_cache.dart';

/// Callback signature for [MutationObserver] subscribers.
typedef MutationObserverListener = void Function(MutationState state);

/// Bridges between a [Mutation] and UI listeners.
///
/// Provides [mutate] and [mutateAsync] to trigger mutations, with optional
/// per-call callbacks. Subscribers are notified with the latest
/// [MutationState] on each state change.
class MutationObserver<TData, TVariables> extends Subscribable<MutationObserverListener> {
  final MutationCache _cache;
  final nm.NotifyManager _notifyManager;
  MutationConfig<TData, TVariables> _config;
  Mutation<TData, TVariables>? _currentMutation;
  MutationState<TData> _currentResult;

  // Per-call callbacks from mutate()
  void Function(TData data, TVariables variables, Object? context)? _mutateOnSuccess;
  void Function(Object error, TVariables variables, Object? context)? _mutateOnError;
  void Function(TData? data, Object? error, TVariables variables, Object? context)? _mutateOnSettled;

  MutationObserver({
    required MutationCache cache,
    required MutationConfig<TData, TVariables> config,
    nm.NotifyManager? notifyManager,
  })  : _cache = cache,
        _config = config,
        _notifyManager = notifyManager ?? nm.notifyManager,
        _currentResult = MutationState<TData>();

  /// The most recent mutation state snapshot.
  MutationState<TData> get currentResult => _currentResult;

  /// The current configuration for this observer's mutations.
  MutationConfig<TData, TVariables> get config => _config;

  /// Replaces the mutation configuration. Takes effect on the next [mutate] call.
  void setConfig(MutationConfig<TData, TVariables> config) {
    _config = config;
  }

  /// Triggers a mutation with the given [variables]. Does not throw on failure.
  ///
  /// Creates a new [Mutation] in the cache, attaches this observer, and
  /// starts execution. Optional per-call [onSuccess], [onError], and
  /// [onSettled] callbacks fire in addition to the config-level callbacks.
  void mutate(
    TVariables variables, {
    void Function(TData data, TVariables variables, Object? context)? onSuccess,
    void Function(Object error, TVariables variables, Object? context)? onError,
    void Function(TData? data, Object? error, TVariables variables, Object? context)? onSettled,
  }) {
    _mutateOnSuccess = onSuccess;
    _mutateOnError = onError;
    _mutateOnSettled = onSettled;

    _currentMutation?.removeObserver(_onMutationUpdate);
    _currentMutation = _cache.build<TData, TVariables>(config: _config);
    _currentMutation!.addObserver(_onMutationUpdate);

    _currentMutation!.execute(variables).then((_) {}, onError: (_) {});
  }

  /// Like [mutate], but returns a Future that resolves with the result or
  /// throws on failure. Use when you need to await the mutation outcome.
  Future<TData> mutateAsync(
    TVariables variables, {
    void Function(TData data, TVariables variables, Object? context)? onSuccess,
    void Function(Object error, TVariables variables, Object? context)? onError,
    void Function(TData? data, Object? error, TVariables variables, Object? context)? onSettled,
  }) {
    _mutateOnSuccess = onSuccess;
    _mutateOnError = onError;
    _mutateOnSettled = onSettled;

    _currentMutation?.removeObserver(_onMutationUpdate);
    _currentMutation = _cache.build<TData, TVariables>(config: _config);
    _currentMutation!.addObserver(_onMutationUpdate);

    return _currentMutation!.execute(variables);
  }

  /// Detaches from the current mutation and resets state to idle.
  void reset() {
    _currentMutation?.removeObserver(_onMutationUpdate);
    _currentMutation = null;
    _currentResult = MutationState<TData>();
    _notify();
  }

  void _onMutationUpdate(MutationActionType action) {
    _updateResult();
    _notifyManager.batch(() {
      // Per-call callbacks fire first (regardless of subscriber count)
      final mutation = _currentMutation;
      if (mutation != null) {
        if (action == MutationActionType.success && _mutateOnSuccess != null) {
          try {
            _mutateOnSuccess!(
              mutation.state.data as TData,
              mutation.state.variables as TVariables,
              mutation.state.context,
            );
          } catch (_) {}
        }
        if (action == MutationActionType.error && _mutateOnError != null) {
          try {
            _mutateOnError!(
              mutation.state.error!,
              mutation.state.variables as TVariables,
              mutation.state.context,
            );
          } catch (_) {}
        }
        if ((action == MutationActionType.success || action == MutationActionType.error) &&
            _mutateOnSettled != null) {
          try {
            _mutateOnSettled!(
              mutation.state.data,
              mutation.state.error,
              mutation.state.variables as TVariables,
              mutation.state.context,
            );
          } catch (_) {}
        }
      }
      // Then notify subscribers
      _notify();
    });
  }

  void _updateResult() {
    _currentResult = _currentMutation?.state ?? MutationState<TData>();
  }

  void _notify() {
    for (final listener in listeners) {
      listener(_currentResult);
    }
  }

  @override
  void onUnsubscribe() {
    if (!hasListeners) {
      _currentMutation?.removeObserver(_onMutationUpdate);
    }
  }
}
