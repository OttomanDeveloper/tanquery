import 'package:test/test.dart';
import 'package:dart_query/src/utils/time_utils.dart';

void main() {
  group('defaultRetryDelay', () {
    test('exponential backoff', () {
      expect(defaultRetryDelay(0), const Duration(milliseconds: 1000));
      expect(defaultRetryDelay(1), const Duration(milliseconds: 2000));
      expect(defaultRetryDelay(2), const Duration(milliseconds: 4000));
      expect(defaultRetryDelay(3), const Duration(milliseconds: 8000));
    });

    test('caps at 30 seconds', () {
      expect(defaultRetryDelay(5), const Duration(milliseconds: 30000));
      expect(defaultRetryDelay(10), const Duration(milliseconds: 30000));
    });
  });

  group('isValidTimeout', () {
    test('valid durations', () {
      expect(isValidTimeout(const Duration(seconds: 5)), isTrue);
      expect(isValidTimeout(const Duration(milliseconds: 1)), isTrue);
    });

    test('null is invalid', () {
      expect(isValidTimeout(null), isFalse);
    });

    test('zero is invalid', () {
      expect(isValidTimeout(Duration.zero), isFalse);
    });

    test('negative is invalid', () {
      expect(isValidTimeout(const Duration(seconds: -1)), isFalse);
    });
  });

  group('timeUntilStale', () {
    test('returns zero when already stale', () {
      final updatedAt = DateTime.now().subtract(const Duration(minutes: 10));
      final result = timeUntilStale(updatedAt, const Duration(minutes: 5));
      expect(result, Duration.zero);
    });

    test('returns remaining time when not stale', () {
      final updatedAt = DateTime.now();
      final result = timeUntilStale(updatedAt, const Duration(minutes: 5));
      expect(result.inMinutes, greaterThanOrEqualTo(4));
    });
  });
}
