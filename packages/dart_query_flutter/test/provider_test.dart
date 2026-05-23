import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_query/dart_query.dart' show QueryClient, QueryKey, NetworkMode;
import 'package:dart_query_flutter/dart_query_flutter.dart';

void main() {
  testWidgets('DartQueryProvider provides client to descendants', (tester) async {
    final client = QueryClient();
    QueryClient? foundClient;

    await tester.pumpWidget(
      DartQueryProvider(
        client: client,
        child: Builder(
          builder: (context) {
            foundClient = DartQuery.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(foundClient, same(client));
    client.clear();
  });

  testWidgets('DartQuery.of throws without provider', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          expect(() => DartQuery.of(context), throwsA(isA<FlutterError>()));
          return const SizedBox();
        },
      ),
    );
  });

  testWidgets('QueryBuilder renders loading then data', (tester) async {
    final client = QueryClient();

    await tester.pumpWidget(
      DartQueryProvider(
        client: client,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: QueryBuilder<String>(
            queryKey: QueryKey(['test_render']),
            queryFn: () async => 'hello world',
            networkMode: NetworkMode.always,
            retryCount: 0,
            builder: (context, state) {
              if (state.isLoading) return const Text('Loading...');
              if (state.isSuccess) return Text('Data: ${state.data}');
              return const Text('Unknown');
            },
          ),
        ),
      ),
    );

    // After first frame + async fetch
    await tester.pump();
    await tester.pump();

    expect(find.text('Data: hello world'), findsOneWidget);

    // Cleanup
    client.clear();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 6));
  });

  testWidgets('MutationBuilder fires mutation and shows result', (tester) async {
    final client = QueryClient();

    await tester.pumpWidget(
      DartQueryProvider(
        client: client,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MutationBuilder<String, String>(
            mutationFn: (input) async => 'Result: $input',
            builder: (context, state, mutate, mutateAsync) {
              if (state.isIdle) {
                return GestureDetector(
                  onTap: () => mutate('test'),
                  child: const Text('Tap to mutate'),
                );
              }
              if (state.isSuccess) return Text('Success: ${state.data}');
              return const Text('...');
            },
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Tap to mutate'), findsOneWidget);
    await tester.tap(find.text('Tap to mutate'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Success: Result: test'), findsOneWidget);

    client.clear();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 6));
  });

  testWidgets('QueryBuilder shows placeholder while loading', (tester) async {
    final client = QueryClient();

    await tester.pumpWidget(
      DartQueryProvider(
        client: client,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: QueryBuilder<String>(
            queryKey: QueryKey(['placeholder_test']),
            queryFn: () async {
              await Future.delayed(const Duration(seconds: 1));
              return 'real data';
            },
            placeholderData: 'placeholder',
            networkMode: NetworkMode.always,
            retryCount: 0,
            builder: (context, state) {
              if (state.isPlaceholderData) return Text('PH: ${state.data}');
              if (state.isSuccess && !state.isPlaceholderData) return Text('Real: ${state.data}');
              return const Text('Loading...');
            },
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('PH: placeholder'), findsOneWidget);

    client.clear();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 6));
  });
}
