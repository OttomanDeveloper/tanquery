import 'package:test/test.dart';
import 'package:dart_query/src/utils/hash_key.dart';

void main() {
  group('hashQueryKey', () {
    test('hashes simple string key', () {
      expect(hashQueryKey(['todos']), '["todos"]');
    });

    test('hashes numeric key parts', () {
      expect(hashQueryKey(['todos', 1]), '["todos",1]');
    });

    test('sorts map keys for deterministic hash', () {
      final hash1 = hashQueryKey([
        {'b': 2, 'a': 1}
      ]);
      final hash2 = hashQueryKey([
        {'a': 1, 'b': 2}
      ]);
      expect(hash1, hash2);
    });

    test('sorts nested map keys', () {
      final hash1 = hashQueryKey([
        {
          'outer': {'b': 2, 'a': 1}
        }
      ]);
      final hash2 = hashQueryKey([
        {
          'outer': {'a': 1, 'b': 2}
        }
      ]);
      expect(hash1, hash2);
    });

    test('does not sort lists', () {
      final hash1 = hashQueryKey([
        [1, 2, 3]
      ]);
      final hash2 = hashQueryKey([
        [3, 2, 1]
      ]);
      expect(hash1, isNot(hash2));
    });

    test('handles null values', () {
      expect(hashQueryKey(['key', null]), '["key",null]');
    });

    test('handles bool values', () {
      expect(hashQueryKey([true, false]), '[true,false]');
    });

    test('handles empty key', () {
      expect(hashQueryKey([]), '[]');
    });
  });
}
