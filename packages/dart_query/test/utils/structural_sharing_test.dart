import 'package:test/test.dart';
import 'package:dart_query/src/utils/structural_sharing.dart';

void main() {
  group('replaceEqualDeep', () {
    test('returns old reference if identical', () {
      final list = [1, 2, 3];
      final result = replaceEqualDeep(list, list);
      expect(identical(result, list), isTrue);
    });

    test('returns old reference if deeply equal list', () {
      final old = [1, 2, 3];
      final fresh = [1, 2, 3];
      final result = replaceEqualDeep(old, fresh);
      expect(identical(result, old), isTrue);
    });

    test('returns old reference if deeply equal map', () {
      final old = <String, int>{'a': 1, 'b': 2};
      final fresh = <String, int>{'a': 1, 'b': 2};
      final result = replaceEqualDeep(old, fresh);
      expect(identical(result, old), isTrue);
    });

    test('returns new value if different', () {
      final old = {'a': 1};
      final fresh = {'a': 2};
      final result = replaceEqualDeep(old, fresh);
      expect(result, {'a': 2});
      expect(identical(result, old), isFalse);
    });

    test('preserves unchanged nested references', () {
      final nested = [1, 2, 3];
      final old = <String, Object>{'a': nested, 'b': 'old'};
      final fresh = <String, Object>{'a': [1, 2, 3], 'b': 'new'};
      final result = replaceEqualDeep(old, fresh) as Map;
      expect(identical(result['a'], nested), isTrue);
      expect(result['b'], 'new');
    });

    test('returns new value at depth > 500', () {
      final old = {'a': 1};
      final fresh = {'a': 1};
      final result = replaceEqualDeep(old, fresh, depth: 501);
      expect(identical(result, fresh), isTrue);
    });

    test('handles null values', () {
      expect(replaceEqualDeep(null, null), isNull);
    });

    test('handles primitive equality', () {
      final old = 42;
      final result = replaceEqualDeep(old, 42);
      expect(identical(result, old), isTrue);
    });

    test('different length lists return new list', () {
      final old = [1, 2];
      final fresh = [1, 2, 3];
      final result = replaceEqualDeep(old, fresh) as List;
      expect(result, [1, 2, 3]);
      expect(identical(result, old), isFalse);
    });
  });
}
