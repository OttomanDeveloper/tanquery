import 'dart:async';
import 'package:test/test.dart';
import 'package:dart_query/src/models/types.dart';
import 'package:dart_query/src/streamed/streamed_query.dart';

void main() {
  group('streamedQuery', () {
    test('accumulates stream chunks with reducer', () async {
      final queryFn = streamedQuery<int, List<int>>(
        streamFn: () => Stream.fromIterable([1, 2, 3]),
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [],
      );

      final result = await queryFn();
      expect(result, [1, 2, 3]);
    });

    test('works with string concatenation', () async {
      final queryFn = streamedQuery<String, String>(
        streamFn: () => Stream.fromIterable(['hello', ' ', 'world']),
        reducer: (acc, chunk) => acc + chunk,
        initialValue: '',
      );

      final result = await queryFn();
      expect(result, 'hello world');
    });

    test('calls onData for each chunk', () async {
      final updates = <List<int>>[];
      final queryFn = streamedQuery<int, List<int>>(
        streamFn: () => Stream.fromIterable([1, 2, 3]),
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [],
        onData: (data) => updates.add(List.from(data)),
      );

      await queryFn();
      expect(updates, [
        [1],
        [1, 2],
        [1, 2, 3],
      ]);
    });

    test('returns initialValue for empty stream', () async {
      final queryFn = streamedQuery<int, List<int>>(
        streamFn: () => const Stream.empty(),
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [0],
      );

      final result = await queryFn();
      expect(result, [0]);
    });

    test('works with async stream controller', () async {
      final controller = StreamController<String>();

      final queryFn = streamedQuery<String, List<String>>(
        streamFn: () => controller.stream,
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [],
      );

      final future = queryFn();

      controller.add('a');
      controller.add('b');
      controller.add('c');
      await controller.close();

      final result = await future;
      expect(result, ['a', 'b', 'c']);
    });

    test('propagates stream errors', () async {
      final queryFn = streamedQuery<int, List<int>>(
        streamFn: () => Stream.error(Exception('stream error')),
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [],
      );

      await expectLater(queryFn(), throwsException);
    });

    test('reset mode starts from initialValue', () async {
      final queryFn = streamedQuery<int, List<int>>(
        streamFn: () => Stream.fromIterable([4, 5]),
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [],
        refetchMode: RefetchMode.reset,
        getCurrentData: () => [1, 2, 3],
      );
      final result = await queryFn();
      expect(result, [4, 5]); // ignores existing [1,2,3]
    });

    test('append mode keeps existing data', () async {
      final queryFn = streamedQuery<int, List<int>>(
        streamFn: () => Stream.fromIterable([4, 5]),
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [],
        refetchMode: RefetchMode.append,
        getCurrentData: () => [1, 2, 3],
      );
      final result = await queryFn();
      expect(result, [1, 2, 3, 4, 5]); // appends to existing
    });

    test('replace mode does not call onData per chunk', () async {
      final updates = <List<int>>[];
      final queryFn = streamedQuery<int, List<int>>(
        streamFn: () => Stream.fromIterable([1, 2, 3]),
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [],
        refetchMode: RefetchMode.replace,
        onData: (data) => updates.add(List.from(data)),
      );
      final result = await queryFn();
      expect(result, [1, 2, 3]);
      expect(updates, isEmpty); // replace mode: no progressive updates
    });

    test('append falls back to initialValue when no existing data', () async {
      final queryFn = streamedQuery<int, List<int>>(
        streamFn: () => Stream.fromIterable([1, 2]),
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [0],
        refetchMode: RefetchMode.append,
        getCurrentData: () => null,
      );
      final result = await queryFn();
      expect(result, [0, 1, 2]); // uses initialValue since no existing
    });
  });
}
