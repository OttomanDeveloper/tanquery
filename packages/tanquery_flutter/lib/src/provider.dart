import 'package:flutter/widgets.dart';
import 'package:tanquery/tanquery.dart' as dq;
import 'package:tanquery/tanquery.dart' show QueryClient;

/// Provides a [QueryClient] to the widget tree.
///
/// Place this near the root of your app, above any widgets that use
/// [QueryBuilder] or [MutationBuilder]. Handles mounting/unmounting
/// the client and forwarding app lifecycle events to [FocusManager].
///
/// ```dart
/// DartQueryProvider(
///   client: QueryClient(),
///   child: MaterialApp(...),
/// )
/// ```
class DartQueryProvider extends StatefulWidget {
  /// The [QueryClient] instance shared with all descendant widgets.
  final QueryClient client;

  /// The widget subtree that will have access to [client].
  final Widget child;

  /// Creates a provider that makes [client] available to the widget tree.
  const DartQueryProvider({
    super.key,
    required this.client,
    required this.child,
  });

  @override
  State<DartQueryProvider> createState() => _DartQueryProviderState();
}

class _DartQueryProviderState extends State<DartQueryProvider>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    widget.client.mount();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(DartQueryProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client) {
      oldWidget.client.unmount();
      widget.client.mount();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.client.unmount();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final focusManager = dq.FocusManager.instance;
    switch (state) {
      case AppLifecycleState.resumed:
        focusManager.setFocused(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        focusManager.setFocused(false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DartQueryInherited(
      client: widget.client,
      child: widget.child,
    );
  }
}

class _DartQueryInherited extends InheritedWidget {
  final QueryClient client;

  const _DartQueryInherited({
    required this.client,
    required super.child,
  });

  @override
  bool updateShouldNotify(_DartQueryInherited oldWidget) {
    return client != oldWidget.client;
  }
}

/// Static accessor for the nearest [QueryClient] in the widget tree.
class DartQuery {
  /// Looks up the nearest [QueryClient] from the widget tree.
  ///
  /// Throws a [FlutterError] with setup instructions if no
  /// [DartQueryProvider] is found above this context.
  static QueryClient of(BuildContext context) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<_DartQueryInherited>();
    if (widget == null) {
      throw FlutterError(
        'DartQuery.of() called without a DartQueryProvider ancestor.\n'
        'Wrap your app with DartQueryProvider:\n'
        '  DartQueryProvider(\n'
        '    client: queryClient,\n'
        '    child: MaterialApp(...),\n'
        '  )',
      );
    }
    return widget.client;
  }
}
