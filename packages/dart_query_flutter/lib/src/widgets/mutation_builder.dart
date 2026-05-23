import 'package:flutter/widgets.dart';
import 'package:dart_query/dart_query.dart';
import '../provider.dart';

typedef MutationWidgetBuilder<TData, TVariables> = Widget Function(
  BuildContext context,
  MutationState<TData> state,
  void Function(TVariables variables) mutate,
  Future<TData> Function(TVariables variables) mutateAsync,
);

class MutationBuilder<TData, TVariables> extends StatefulWidget {
  final MutationFn<TData, TVariables> mutationFn;
  final MutationWidgetBuilder<TData, TVariables> builder;
  final MutationScope? scope;
  final int retryCount;
  final Future<Object?> Function(TVariables variables)? onMutate;
  final Future<void> Function(TData data, TVariables variables, Object? context)? onSuccess;
  final Future<void> Function(Object error, TVariables variables, Object? context)? onError;
  final Future<void> Function(TData? data, Object? error, TVariables variables, Object? context)? onSettled;

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
