library dart_query_flutter;

// Re-export core types that widgets need (hide FocusManager to avoid Flutter collision)
export 'package:dart_query/dart_query.dart'
    hide FocusManager, focusManager, Subscribable, Removable;

// Provider
export 'src/provider.dart';

// Widgets
export 'src/widgets/query_builder.dart';
export 'src/widgets/mutation_builder.dart';
export 'src/widgets/infinite_query_builder.dart';
export 'src/widgets/queries_builder.dart';
