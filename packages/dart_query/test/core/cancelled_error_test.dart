import 'package:test/test.dart';
import 'package:dart_query/src/core/cancelled_error.dart';

void main() {
  group('CancelledError', () {
    test('defaults to no revert and no silent', () {
      final error = CancelledError();
      expect(error.revert, isFalse);
      expect(error.silent, isFalse);
    });

    test('accepts revert flag', () {
      final error = CancelledError(revert: true);
      expect(error.revert, isTrue);
    });

    test('accepts silent flag', () {
      final error = CancelledError(silent: true);
      expect(error.silent, isTrue);
    });

    test('isCancelledError identifies correctly', () {
      expect(isCancelledError(CancelledError()), isTrue);
      expect(isCancelledError(Exception('other')), isFalse);
      expect(isCancelledError('string'), isFalse);
    });

    test('has descriptive message', () {
      final error = CancelledError();
      expect(error.toString(), contains('CancelledError'));
    });
  });
}
