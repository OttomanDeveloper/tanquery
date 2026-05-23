import 'package:flutter/widgets.dart';
import 'package:tanquery/tanquery.dart';
import '../provider.dart';

/// Signature for the builder function passed to [MutationBuilder].
///
/// Receives the current [MutationState], a fire-and-forget [mutate] callback,
/// and an async [mutateAsync] callback that returns the result or throws.
typedef MutationWidgetBuilder<TData, TVariables> = Widget Function(
  BuildContext context,
  MutationState<TData> state,
  void Function(TVariables variables) mutate,
  Future<TData> Function(TVariables variables) mutateAsync,
);

/// Builds a widget that can trigger and track a mutation (create, update, delete).
///
/// The [builder] receives the current [MutationState] plus two callbacks:
/// `mutate` (fire-and-forget) and `mutateAsync` (returns a Future).
///
/// ```dart
/// MutationBuilder<Todo, CreateTodoInput>(
///   mutationFn: (input) => api.createTodo(input),
///   onSuccess: (data, variables, ctx) async {
///     queryClient.invalidateQueries(QueryKey(['todos']));
///   },
///   builder: (context, state, mutate, mutateAsync) {
///     return ElevatedButton(
///       onPressed: state.isPending
///           ? null
///           : () => mutate(CreateTodoInput(title: 'New')),
///       child: Text(state.isPending ? 'Saving...' : 'Add Todo'),
///     );
///   },
/// )
/// ```
class MutationBuilder<TData, TVariables> extends StatefulWidget {
  /// Function that performs the mutation. Receives [TVariables] and returns
  /// a Future resolving to [TData].
  final MutationFn<TData, TVariables> mutationFn;

  /// Builder called whenever the mutation state changes.
  final MutationWidgetBuilder<TData, TVariables> builder;

  /// Optional scope for deduplication. Mutations in the same scope run serially.
  final MutationScope? scope;

  /// Number of times to retry on failure. Defaults to 0 (no retries).
  final int retryCount;

  /// Called before the mutation fires. Return value is passed as `context`
  /// to [onSuccess], [onError], and [onSettled], useful for optimistic updates.
  final Future<Object?> Function(TVariables variables)? onMutate;

  /// Called when the mutation succeeds. Receives the returned [data],
  /// the [variables] that were passed in, and the [context] from [onMutate].
  final Future<void> Function(TData data, TVariables variables, Object? context)? onSuccess;

  /// Called when the mutation fails.
  final Future<void> Function(Object error, TVariables variables, Object? context)? onError;

  /// Called after the mutation finishes, regardless of success or failure.
  final Future<void> Function(TData? data, Object? error, TVariables variables, Object? context)? onSettled;

  /// Creates a [MutationBuilder].
  const MutationBuilder({
    super.key,
    required this.mutationFn,
    required this.builder,
    this.scope,
    this.retryCount = 0,
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
  });

  @override
  State<MutationBuilder<TData, TVariables>> createState() =>
      _MutationBuilderState<TData, TVariables>();
}

class _MutationBuilderState<TData, TVariables>
    extends State<MutationBuilder<TData, TVariables>> {
  MutationObserver<TData, TVariables>? _observer;
  Unsubscribe? _unsubscribe;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_observer == null) {
      _createObserver();
      _subscribe();
    }
  }

  @override
  void didUpdateWidget(MutationBuilder<TData, TVariables> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _observer?.setConfig(MutationConfig<TData, TVariables>(
      mutationFn: widget.mutationFn,
      scope: widget.scope,
      retryCount: widget.retryCount,
      onMutate: widget.onMutate,
      onSuccess: widget.onSuccess,
      onError: widget.onError,
      onSettled: widget.onSettled,
    ));
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  void _createObserver() {
    final client = DartQuery.of(context);
    _observer = MutationObserver<TData, TVariables>(
      cache: client.getMutationCache(),
      config: MutationConfig<TData, TVariables>(
        mutationFn: widget.mutationFn,
        scope: widget.scope,
        retryCount: widget.retryCount,
        onMutate: widget.onMutate,
        onSuccess: widget.onSuccess,
        onError: widget.onError,
        onSettled: widget.onSettled,
      ),
    );
  }

  void _subscribe() {
    _unsubscribe = _observer!.subscribe((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_observer == null) return const SizedBox.shrink();
    return widget.builder(
      context,
      _observer!.currentResult,
      (variables) => _observer!.mutate(variables),
      (variables) => _observer!.mutateAsync(variables),
    );
  }
}
