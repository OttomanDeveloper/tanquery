import 'package:test/test.dart';
import 'package:dart_query/src/utils/list_utils.dart';

void main() {
  group('addToEnd', () {
    test('appends item', () {
      expect(addToEnd([1, 2], 3), [1, 2, 3]);
    });

    test('drops first when max exceeded', () {
      expect(addToEnd([1, 2, 3], 4, max: 3), [2, 3, 4]);
    });

    test('no drop when within max', () {
      expect(addToEnd([1, 2], 3, max: 5), [1, 2, 3]);
    });

    test('no drop when max is 0', () {
      expect(addToEnd([1, 2, 3, 4, 5], 6, max: 0), [1, 2, 3, 4, 5, 6]);
    });
  });

  group('addToStart', () {
    test('prepends item', () {
      expect(addToStart([2, 3], 1), [1, 2, 3]);
    });

    test('drops last when max exceeded', () {
      expect(addToStart([1, 2, 3], 0, max: 3), [0, 1, 2]);
    });

    test('no drop when within max', () {
      expect(addToStart([2, 3], 1, max: 5), [1, 2, 3]);
    });
  });
}
