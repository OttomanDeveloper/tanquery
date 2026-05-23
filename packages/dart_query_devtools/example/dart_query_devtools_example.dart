import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dart_query_flutter/dart_query_flutter.dart';
import 'package:dart_query_devtools/dart_query_devtools.dart';

void main() {
  final queryClient = QueryClient();
  runApp(
    DartQueryProvider(
      client: queryClient,
      child: DartQueryDevtools(
        enabled: kDebugMode,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('DevTools Example')),
            body: QueryBuilder<String>(
              queryKey: QueryKey(['greeting']),
              queryFn: () async {
                await Future.delayed(const Duration(seconds: 1));
                return 'Hello, World!';
              },
              builder: (context, state) {
                if (state.isLoading) return const Center(child: CircularProgressIndicator());
                return Center(child: Text(state.data ?? ''));
              },
            ),
          ),
        ),
      ),
    ),
  );
}
