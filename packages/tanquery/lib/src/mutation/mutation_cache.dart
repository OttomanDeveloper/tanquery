import '../core/notify_manager.dart' as nm;
import '../core/subscribable.dart';
import '../core/focus_manager.dart' as fm;
import '../core/online_manager.dart' as om;
import '../models/mutation_state.dart';
import '../models/types.dart';
import 'mutation.dart';

/// Describes a lifecycle event emitted by the [MutationCache].
final class MutationCacheEvent {
  /// What happened (added, removed, updated, observerAdded, observerRemoved).
  final EventType type;

  /// The mutation this event relates to.
  final Mutation mutation;

  /// For update events, the action that triggered the state change.
  final Object? action;

  /// For observer events, the observer that was added or removed.
  final Object? observer;

  const MutationCacheEvent({
    required this.type,
    required this.mutation,
    this.action,
    this.observer,
  });
}

/// Callback signature for [MutationCache] event listeners.
typedef MutationCacheListener = void Function(MutationCacheEvent event);

/// In-memory store of all active mutations, with scope-based serialization.
///
/// Builds new mutations, manages their lifecycle, and ensures scoped
/// mutations execute one at a time within each scope.
class MutationCache extends Subscribable<MutationCacheListener> {
  final Set<Mutation> _mutations = {};
  final Map<String, List<Mutation>> _scopes = {};
  int _mutationId = 0;
  final nm.NotifyManager _notifyManager;
  final fm.FocusManager _focusManager;
  final om.OnlineManager _onlineManager;

  /// Called when any mutation in the cache fails.
  final void Function(Object error, Object? variables, Object? context, Mutation mutation)? onError;

  /// Called when any mutation in the cache succeeds.
  final void Function(Object? data, Object? variables, Object? context, Mutation mutation)? onSuccess;

  /// Called before any mutation in the cache starts executing.
  final void Function(Object? variables, Mutation mutation)? onMutate;

  /// Called after any mutation in the cache finishes, regardless of outcome.
  final void Function(Object? data, Object? error, Object? variables, Object? context, Mutation mutation)? onSettled;

  MutationCache({
    nm.NotifyManager? notifyManager,
    fm.FocusManager? focusManager,
    om.OnlineManager? onlineManager,
    this.onError,
    this.onSuccess,
    this.onMutate,
    this.onSettled,
  })  : _notifyManager = notifyManager ?? nm.notifyManager,
        _focusManager = focusManager ?? fm.focusManager,
        _onlineManager = onlineManager ?? om.onlineManager;

  /// Creates a new [Mutation] with the given [config] and adds it to the cache.
  ///
  /// Unlike [QueryCache.build], each call always creates a fresh mutation.
  /// The mutation is automatically wired up with scope checks and cache
  /// callbacks.
  Mutation<TData, TVariables> build<TData, TVariables>({
    required MutationConfig<TData, TVariables> config,
    MutationState<TData>? state,
  }) {
    final mutation = Mutation<TData, TVariables>(
      mutationId: ++_mutationId,
      config: config,
      state: state,
      canRunCheck: (m) => canRun(m),
      runNextCallback: (m) => runNext(m),
      cacheNotify: (event) => _handleMutationNotify(event),
      cacheCallbacks: CacheLevelCallbacks(
        onMutate: onMutate != null
            ? (variables, mutation) async => onMutate!(variables, mutation as Mutation)
            : null,
        onSuccess: onSuccess != null
            ? (data, variables, context, mutation) async =>
                onSuccess!(data, variables, context, mutation as Mutation)
            : null,
        onError: onError != null
            ? (error, variables, context, mutation) async =>
                onError!(error, variables, context, mutation as Mutation)
            : null,
        onSettled: onSettled != null
            ? (data, error, variables, context, mutation) async =>
                onSettled!(data, error, variables, context, mutation as Mutation)
            : null,
      ),
      notifyManager: _notifyManager,
      focusManager: _focusManager,
      onlineManager: _onlineManager,
    );
    _add(mutation);
    return mutation;
  }

  void _add(Mutation mutation) {
    _mutations.add(mutation);
    final scopeId = mutation.scope?.id;
    if (scopeId != null) {
      _scopes.putIfAbsent(scopeId, () => []).add(mutation);
    }
    _notify(MutationCacheEvent(type: EventType.added, mutation: mutation));
  }

  /// Removes a mutation from the cache and destroys it.
  void remove(Mutation mutation) {
    _mutations.remove(mutation);
    final scopeId = mutation.scope?.id;
    if (scopeId != null) {
      _scopes[scopeId]?.remove(mutation);
      if (_scopes[scopeId]?.isEmpty ?? false) {
        _scopes.remove(scopeId);
      }
    }
    mutation.destroy();
    _notify(MutationCacheEvent(type: EventType.removed, mutation: mutation));
  }

  /// Returns true if the given [mutation] can execute now.
  ///
  /// Unscoped mutations always return true. Scoped mutations can only run
  /// if they are the first pending mutation in their scope's queue.
  bool canRun(Mutation mutation) {
    final scopeId = mutation.scope?.id;
    if (scopeId == null) return true;
    final scopeQueue = _scopes[scopeId] ?? [];
    final firstPending = scopeQueue.cast<Mutation?>().firstWhere(
          (m) => m!.state.isPending,
          orElse: () => null,
        );
    return firstPending == null || identical(firstPending, mutation);
  }

  /// Finds the next paused mutation in the same scope as [completedMutation]
  /// and resumes it. Called automatically after a scoped mutation finishes.
  void runNext(Mutation completedMutation) {
    final scopeId = completedMutation.scope?.id;
    if (scopeId == null) return;
    final scopeQueue = _scopes[scopeId] ?? [];
    final next = scopeQueue.cast<Mutation?>().firstWhere(
          (m) => m!.state.isPaused && !identical(m, completedMutation),
          orElse: () => null,
        );
    next?.continueExecution();
  }

  /// Resumes all paused mutations in parallel. Typically called when
  /// network connectivity is restored.
  Future<void> resumePausedMutations() async {
    final paused = getAll().where((m) => m.state.isPaused).toList();
    await Future.wait(
      paused.map((m) async {
        try {
          await m.continueExecution();
        } catch (_) {}
      }),
    );
  }

  /// Returns all mutations currently in the cache.
  List<Mutation> getAll() => _mutations.toList();

  /// Returns mutations matching the given filters.
  ///
  /// Filter by [status] and/or a custom [predicate]. With no filters,
  /// returns everything.
  List<Mutation> findAll({
    MutationStatus? status,
    bool Function(Mutation)? predicate,
  }) {
    var results = getAll();
    if (status != null) {
      results = results.where((m) => m.state.status == status).toList();
    }
    if (predicate != null) {
      results = results.where(predicate).toList();
    }
    return results;
  }

  /// Removes and destroys all mutations in the cache.
  void clear() {
    _notifyManager.batch(() {
      for (final mutation in getAll()) {
        remove(mutation);
      }
    });
  }

  void _notify(MutationCacheEvent event) {
    _notifyManager.batch(() {
      for (final listener in listeners) {
        listener(event);
      }
    });
  }

  void _handleMutationNotify(Map<String, Object?> event) {
    final mutation = event['mutation'] as Mutation;
    final type = event['type'];

    if (type is EventType) {
      _notify(MutationCacheEvent(
        type: type,
        mutation: mutation,
        action: event['action'],
        observer: event['observer'],
      ));
    }

    if (type == 'requestRemove') {
      remove(mutation);
    }
  }
}
