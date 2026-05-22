import 'package:test/test.dart';
import 'package:dart_query/src/core/subscribable.dart';

class TestSubscribable extends Subscribable<void Function()> {
  int subscribeCount = 0;
  int unsubscribeCount = 0;

  @override
  void onSubscribe() => subscribeCount++;

  @override
  void onUnsubscribe() => unsubscribeCount++;

  void notify() {
    for (final listener in listeners) {
      listener();
    }
  }
}

void main() {
  group('Subscribable', () {
    late TestSubscribable subscribable;

    setUp(() => subscribable = TestSubscribable());

    test('starts with no listeners', () {
      expect(subscribable.hasListeners, isFalse);
    });

    test('subscribe adds listener and returns unsubscribe', () {
      var called = false;
      final unsubscribe = subscribable.subscribe(() => called = true);
      expect(subscribable.hasListeners, isTrue);
      subscribable.notify();
      expect(called, isTrue);
      unsubscribe();
      expect(subscribable.hasListeners, isFalse);
    });

    test('calls onSubscribe for each subscribe', () {
      subscribable.subscribe(() {});
      expect(subscribable.subscribeCount, 1);
      subscribable.subscribe(() {});
      expect(subscribable.subscribeCount, 2);
    });

    test('calls onUnsubscribe for each unsubscribe', () {
      final unsub1 = subscribable.subscribe(() {});
      final unsub2 = subscribable.subscribe(() {});
      unsub1();
      expect(subscribable.unsubscribeCount, 1);
      unsub2();
      expect(subscribable.unsubscribeCount, 2);
    });

    test('double unsubscribe is safe', () {
      final unsub = subscribable.subscribe(() {});
      unsub();
      unsub();
      expect(subscribable.unsubscribeCount, 2);
    });

    test('Set prevents duplicate listeners', () {
      var count = 0;
      void listener() => count++;
      subscribable.subscribe(listener);
      subscribable.subscribe(listener);
      subscribable.notify();
      expect(count, 1);
    });
  });
}
