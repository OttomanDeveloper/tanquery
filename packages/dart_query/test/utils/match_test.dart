import 'package:test/test.dart';
import 'package:dart_query/src/utils/match.dart';

void main() {
  group('partialMatchKey', () {
    test('identical values match', () {
      expect(partialMatchKey('a', 'a'), isTrue);
    });

    test('different types do not match', () {
      expect(partialMatchKey('a', 1), isFalse);
    });

    test('list prefix matches', () {
      expect(partialMatchKey(['a', 'b', 'c'], ['a']), isTrue);
      expect(partialMatchKey(['a', 'b', 'c'], ['a', 'b']), isTrue);
      expect(partialMatchKey(['a', 'b', 'c'], ['a', 'b', 'c']), isTrue);
    });

    test('list non-prefix does not match', () {
      expect(partialMatchKey(['a'], ['a', 'b']), isFalse);
    });

    test('map subset matches', () {
      expect(partialMatchKey({'a': 1, 'b': 2}, {'a': 1}), isTrue);
    });

    test('map non-subset does not match', () {
      expect(partialMatchKey({'a': 1}, {'a': 1, 'b': 2}), isFalse);
    });

    test('nested structures', () {
      expect(
        partialMatchKey(
          ['todos', {'status': 'active', 'page': 1}],
          ['todos', {'status': 'active'}],
        ),
        isTrue,
      );
    });

    test('deeply nested map', () {
      expect(
        partialMatchKey(
          {'a': {'b': {'c': 1, 'd': 2}}},
          {'a': {'b': {'c': 1}}},
        ),
        isTrue,
      );
    });

    test('null values', () {
      expect(partialMatchKey(null, null), isTrue);
      expect(partialMatchKey(null, 'a'), isFalse);
    });

    test('empty list matches anything', () {
      expect(partialMatchKey(['a', 'b'], []), isTrue);
    });

    test('different list values do not match', () {
      expect(partialMatchKey(['a', 'b'], ['a', 'c']), isFalse);
    });
  });
}
