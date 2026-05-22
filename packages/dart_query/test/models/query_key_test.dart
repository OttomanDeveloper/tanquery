import 'package:test/test.dart';
import 'package:dart_query/src/models/query_key.dart';

void main() {
  group('QueryKey', () {
    test('equality by hash', () {
      final a = QueryKey(['todos']);
      final b = QueryKey(['todos']);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('inequality for different keys', () {
      final a = QueryKey(['todos']);
      final b = QueryKey(['users']);
      expect(a, isNot(equals(b)));
    });

    test('map key order does not matter', () {
      final a = QueryKey([
        {'a': 1, 'b': 2}
      ]);
      final b = QueryKey([
        {'b': 2, 'a': 1}
      ]);
      expect(a, equals(b));
    });

    test('parameterized keys are distinct', () {
      final a = QueryKey(['todos', 1]);
      final b = QueryKey(['todos', 2]);
      expect(a, isNot(equals(b)));
    });

    test('hash is computed eagerly', () {
      final key = QueryKey(['todos', 'list']);
      expect(key.queryHash, '["todos","list"]');
    });

    test('toString is readable', () {
      final key = QueryKey(['todos', 1]);
      expect(key.toString(), contains('todos'));
    });

    test('can be used as Map key', () {
      final map = <QueryKey, String>{};
      map[QueryKey(['test'])] = 'value';
      expect(map[QueryKey(['test'])], 'value');
    });
  });
}
