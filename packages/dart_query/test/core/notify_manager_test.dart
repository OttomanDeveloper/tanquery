import 'package:test/test.dart';
import 'package:dart_query/src/core/notify_manager.dart';

void main() {
  group('NotifyManager', () {
    late NotifyManager manager;

    setUp(() {
      manager = NotifyManager();
      manager.setScheduler((cb) => cb());
    });

    test('schedule executes callback outside batch', () {
      var called = false;
      manager.schedule(() => called = true);
      expect(called, isTrue);
    });

    test('batch queues and flushes callbacks', () {
      final order = <int>[];
      manager.batch(() {
        manager.schedule(() => order.add(1));
        manager.schedule(() => order.add(2));
        expect(order, isEmpty);
      });
      expect(order, [1, 2]);
    });

    test('nested batches only flush on outermost', () {
      final order = <int>[];
      manager.batch(() {
        manager.schedule(() => order.add(1));
        manager.batch(() {
          manager.schedule(() => order.add(2));
          expect(order, isEmpty);
        });
        expect(order, isEmpty);
      });
      expect(order, [1, 2]);
    });

    test('batch returns callback result', () {
      final result = manager.batch(() => 42);
      expect(result, 42);
    });

    test('batch flushes even if callback throws', () {
      final order = <int>[];
      expect(
        () => manager.batch(() {
          manager.schedule(() => order.add(1));
          throw Exception('oops');
        }),
        throwsException,
      );
      expect(order, [1]);
    });

    test('batchCalls wraps function for batched execution', () {
      final order = <int>[];
      final wrapped = manager.batchCalls((int value) => order.add(value));

      manager.batch(() {
        wrapped(1);
        wrapped(2);
        expect(order, isEmpty);
      });
      expect(order, [1, 2]);
    });

    test('flush swaps queue atomically for re-entrant safety', () {
      final order = <int>[];
      manager.batch(() {
        manager.schedule(() {
          order.add(1);
          // This schedule goes into a NEW queue (not the current one being flushed)
          // With sync scheduler it executes immediately
          manager.schedule(() => order.add(3));
        });
        manager.schedule(() => order.add(2));
      });
      // Callback 1 runs, then 3 (sync schedule), then 2
      expect(order, [1, 3, 2]);
    });
  });
}
