import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';
import 'package:dart_query/src/core/removable.dart';

class TestRemovable extends Removable {
  int removeCount = 0;

  TestRemovable({Duration gcTime = const Duration(minutes: 5)})
      : super(gcTime: gcTime);

  @override
  void optionalRemove() => removeCount++;
}

void main() {
  group('Removable', () {
    test('scheduleGc fires optionalRemove after gcTime', () {
      fakeAsync((async) {
        final removable = TestRemovable(gcTime: const Duration(seconds: 10));
        removable.scheduleGc();
        async.elapse(const Duration(seconds: 9));
        expect(removable.removeCount, 0);
        async.elapse(const Duration(seconds: 1));
        expect(removable.removeCount, 1);
      });
    });

    test('clearGcTimeout prevents removal', () {
      fakeAsync((async) {
        final removable = TestRemovable(gcTime: const Duration(seconds: 5));
        removable.scheduleGc();
        async.elapse(const Duration(seconds: 3));
        removable.clearGcTimeout();
        async.elapse(const Duration(seconds: 10));
        expect(removable.removeCount, 0);
      });
    });

    test('scheduleGc replaces previous timer', () {
      fakeAsync((async) {
        final removable = TestRemovable(gcTime: const Duration(seconds: 5));
        removable.scheduleGc();
        async.elapse(const Duration(seconds: 3));
        removable.scheduleGc();
        async.elapse(const Duration(seconds: 3));
        expect(removable.removeCount, 0);
        async.elapse(const Duration(seconds: 2));
        expect(removable.removeCount, 1);
      });
    });

    test('updateGcTime only increases, never decreases', () {
      final removable = TestRemovable(gcTime: const Duration(minutes: 5));
      removable.updateGcTime(const Duration(minutes: 10));
      expect(removable.gcTime, const Duration(minutes: 10));
      removable.updateGcTime(const Duration(minutes: 3));
      expect(removable.gcTime, const Duration(minutes: 10));
    });

    test('updateGcTime defaults to 5 minutes when null', () {
      final removable = TestRemovable(gcTime: Duration.zero);
      removable.updateGcTime(null);
      expect(removable.gcTime, const Duration(minutes: 5));
    });

    test('destroy clears GC timeout', () {
      fakeAsync((async) {
        final removable = TestRemovable(gcTime: const Duration(seconds: 5));
        removable.scheduleGc();
        removable.destroy();
        async.elapse(const Duration(seconds: 10));
        expect(removable.removeCount, 0);
      });
    });
  });
}
