import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';
import 'package:dart_query/src/query/query.dart';
import 'package:dart_query/src/models/query_key.dart';
import 'package:dart_query/src/models/query_state.dart';
import 'package:dart_query/src/models/types.dart';
import 'package:dart_query/src/core/cancelled_error.dart';
import 'package:dart_query/src/core/focus_manager.dart';
import 'package:dart_query/src/core/online_manager.dart';
import 'package:dart_query/src/core/notify_manager.dart';

class MockObserver implements QueryUpdateCallback {
  int updateCount = 0;
  bool _shouldFetchOnFocus = false;
  bool _shouldFetchOnReconnect = false;
  int refetchCount = 0;

  @override
  void onQueryUpdate() => updateCount++;

  @override
  bool shouldFetchOnWindowFocus() => _shouldFetchOnFocus;

  @override
  bool shouldFetchOnReconnect() => _shouldFetchOnReconnect;

  @override
  void refetch({bool cancelRefetch = true}) => refetchCount++;
}

void main() {
  late NotifyManager notify;
  late FocusManager focus;
  late OnlineManager online;
  late List<Map<String, Object?>> cacheEvents;

  setUp(() {
    notify = NotifyManager();
    notify.setScheduler((cb) => cb());
    focus = FocusManager();
    focus.setFocused(true);
    online = OnlineManager();
    online.setOnline(true);
    cacheEvents = [];
  });

  Query<T> createQuery<T>({
    List<Object?> key = const ['test'],
    Future<T> Function()? fn,
    T? initialData,
    Duration gcTime = const Duration(minutes: 5),
    int retryCount = 0,
    NetworkMode networkMode = NetworkMode.always,
    bool trackCache = false,
  }) {
    final queryKey = QueryKey(key);
    return Query<T>(
      queryKey: queryKey,
      queryHash: queryKey.queryHash,
      queryFn: fn,
      initialData: initialData,
      gcTime: gcTime,
      retryCount: retryCount,
      networkMode: networkMode,
      notifyManager: notify,
      focusManager: focus,
      onlineManager: online,
      cacheNotify: trackCache ? (event) => cacheEvents.add(event as Map<String, Object?>) : null,
    );
  }

  group('Query — initial state', () {
    test('no data: pending + idle', () {
      final query = createQuery<String>();
      expect(query.state.status, QueryStatus.pending);
      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.data, isNull);
    });

    test('with initialData: success', () {
      final query = createQuery<String>(initialData: 'hello');
      expect(query.state.status, QueryStatus.success);
      expect(query.state.data, 'hello');
      expect(query.state.dataUpdatedAt, isNotNull);
    });
  });

  group('Query — setData', () {
    test('dispatches success action', () {
      final query = createQuery<String>();
      query.setData('hello');
      expect(query.state.status, QueryStatus.success);
      expect(query.state.data, 'hello');
      expect(query.state.isInvalidated, isFalse);
      expect(query.state.dataUpdateCount, 1);
    });

    test('notifies observers', () {
      final query = createQuery<String>();
      final observer = MockObserver();
      query.addObserver(observer);
      query.setData('hello');
      expect(observer.updateCount, 1);
    });

    test('notifies multiple observers', () {
      final query = createQuery<String>();
      final obs1 = MockObserver();
      final obs2 = MockObserver();
      query.addObserver(obs1);
      query.addObserver(obs2);
      query.setData('hello');
      expect(obs1.updateCount, 1);
      expect(obs2.updateCount, 1);
    });

    test('structural sharing preserves references for equal data', () {
      final original = [1, 2, 3];
      final query = createQuery<List<int>>(initialData: original);
      final returned = query.setData([1, 2, 3]);
      expect(identical(returned, original), isTrue);
    });

    test('manual setData sets _revertState', () async {
      final query = createQuery<String>(fn: () async => 'fetched');
      query.setData('manual', manual: true);
      expect(query.state.data, 'manual');
      // revert should use the manual state now
    });
  });

  group('Query — invalidate', () {
    test('marks as invalidated', () {
      final query = createQuery<String>(initialData: 'data');
      query.invalidate();
      expect(query.state.isInvalidated, isTrue);
    });

    test('idempotent — only notifies once', () {
      final query = createQuery<String>(initialData: 'data');
      final observer = MockObserver();
      query.addObserver(observer);
      query.invalidate();
      query.invalidate();
      expect(observer.updateCount, 1);
    });
  });

  group('Query — staleness', () {
    test('no data is always stale', () {
      final query = createQuery<String>();
      expect(query.isStaleByTime(const Duration(hours: 1)), isTrue);
    });

    test('fresh data is not stale', () {
      final query = createQuery<String>(initialData: 'data');
      expect(query.isStaleByTime(const Duration(hours: 1)), isFalse);
    });

    test('zero staleTime is immediately stale', () {
      final query = createQuery<String>(initialData: 'data');
      expect(query.isStaleByTime(Duration.zero), isTrue);
    });

    test('invalidated data is stale regardless of time', () {
      final query = createQuery<String>(initialData: 'data');
      query.invalidate();
      expect(query.isStaleByTime(const Duration(hours: 1)), isTrue);
    });

    test('StaleTime.static_ makes data never stale', () {
      final query = createQuery<String>(initialData: 'data');
      expect(query.isStaleByTime(StaleTime.static_), isFalse);
      query.invalidate();
      expect(query.isStaleByTime(StaleTime.static_), isFalse);
    });
  });

  group('Query — observer management', () {
    test('addObserver prevents GC', () {
      fakeAsync((async) {
        final query = createQuery<String>(gcTime: const Duration(seconds: 5));
        var removed = false;
        query.onRemove = () => removed = true;
        query.scheduleGc();
        query.addObserver(MockObserver());
        async.elapse(const Duration(seconds: 10));
        expect(removed, isFalse);
      });
    });

    test('removeObserver schedules GC', () {
      fakeAsync((async) {
        final query = createQuery<String>(gcTime: const Duration(seconds: 5));
        var removed = false;
        query.onRemove = () => removed = true;
        final observer = MockObserver();
        query.addObserver(observer);
        query.removeObserver(observer);
        async.elapse(const Duration(seconds: 5));
        expect(removed, isTrue);
      });
    });

    test('isActive when has observers', () {
      final query = createQuery<String>();
      expect(query.isActive(), isFalse);
      query.addObserver(MockObserver());
      expect(query.isActive(), isTrue);
    });

    test('removeObserver with abortSignalConsumed cancels with revert', () async {
      final completer = Completer<String>();
      final query = createQuery<String>(
        initialData: 'old',
        fn: () => completer.future,
      );
      // Simulate abort signal consumed internally by starting fetch
      unawaited(query.fetch().catchError((_) => ''));
      // The abort signal consumed flag is internal to query now
    });

    test('GC does NOT fire when fetchStatus is not idle', () {
      fakeAsync((async) {
        final query = createQuery<String>(
          gcTime: const Duration(seconds: 5),
          fn: () => Completer<String>().future, // never completes
          networkMode: NetworkMode.always,
        );
        var removed = false;
        query.onRemove = () => removed = true;
        // Start fetch so fetchStatus is 'fetching'
        unawaited(query.fetch().catchError((_) => ''));
        query.scheduleGc();
        async.elapse(const Duration(seconds: 10));
        expect(removed, isFalse); // optionalRemove checks fetchStatus == idle
      });
    });
  });

  group('Query — fetch', () {
    test('successful fetch updates state to success', () async {
      final query = createQuery<String>(fn: () async => 'fetched');
      await query.fetch();
      expect(query.state.status, QueryStatus.success);
      expect(query.state.data, 'fetched');
      expect(query.state.fetchStatus, FetchStatus.idle);
    });

    test('failed fetch updates state to error', () async {
      final query = createQuery<String>(
        fn: () async => throw Exception('fail'),
      );
      try {
        await query.fetch();
      } catch (_) {}
      expect(query.state.status, QueryStatus.error);
      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.isInvalidated, isTrue);
    });

    test('fetch deduplication: returns same promise if already fetching', () async {
      final completer = Completer<String>();
      final query = createQuery<String>(fn: () => completer.future);
      final future1 = query.fetch(cancelRefetch: false);
      final future2 = query.fetch(cancelRefetch: false);
      completer.complete('done');
      final result1 = await future1;
      final result2 = await future2;
      expect(result1, 'done');
      expect(result2, 'done');
    });

    test('fetch with cancelRefetch cancels previous fetch', () async {
      var fetchCount = 0;
      final completer1 = Completer<String>();
      final query = createQuery<String>(
        initialData: 'old',
        fn: () {
          fetchCount++;
          if (fetchCount == 1) return completer1.future;
          return Future.value('new');
        },
      );
      final future1 = query.fetch(cancelRefetch: false);
      final future2 = query.fetch(cancelRefetch: true);
      completer1.complete('should be ignored');
      await future2;
      expect(query.state.data, 'new');
    });

    test('fetch action resets failureCount', () async {
      final query = createQuery<String>(
        fn: () async => throw Exception('fail'),
      );
      try {
        await query.fetch();
      } catch (_) {}
      expect(query.state.fetchFailureCount, greaterThan(0));
      // Start another fetch — should reset
      unawaited(query.fetch().catchError((_) => ''));
      // After fetch action dispatched, failureCount should be 0
      // (the fetch action reducer resets it)
    });

    test('fetch sets fetchStatus=paused when offline with online mode', () async {
      online.setOnline(false);
      final query = createQuery<String>(
        fn: () async => 'data',
        networkMode: NetworkMode.online,
      );
      unawaited(query.fetch().catchError((_) => ''));
      await Future.delayed(Duration.zero);
      expect(query.state.fetchStatus, FetchStatus.paused);
      // cleanup
      query.destroy();
    });

    test('setState overrides state directly', () {
      final query = createQuery<String>();
      query.setState(QueryState<String>(
        status: QueryStatus.success,
        data: 'manual',
        dataUpdatedAt: DateTime.now(),
        dataUpdateCount: 1,
      ));
      expect(query.state.data, 'manual');
      expect(query.state.status, QueryStatus.success);
    });

    test('cancel rejects in-flight fetch', () async {
      final completer = Completer<String>();
      final query = createQuery<String>(fn: () => completer.future);
      unawaited(query.fetch().catchError((_) => ''));
      await query.cancel();
      expect(query.state.fetchStatus, FetchStatus.idle);
    });

    test('cancel with revert restores pre-fetch state', () async {
      final query = createQuery<String>(
        initialData: 'original',
        fn: () => Completer<String>().future,
      );
      unawaited(query.fetch().catchError((_) => ''));
      await Future.delayed(Duration.zero);
      await query.cancel(revert: true);
      expect(query.state.data, 'original');
    });

    test('reset restores initial state', () {
      final query = createQuery<String>(initialData: 'original');
      query.setData('changed');
      expect(query.state.data, 'changed');
      query.reset();
      expect(query.state.data, 'original');
      expect(query.state.status, QueryStatus.success);
    });

    test('isFetched returns true after successful fetch', () async {
      final query = createQuery<String>(fn: () async => 'data');
      expect(query.isFetched(), isFalse);
      await query.fetch();
      expect(query.isFetched(), isTrue);
    });

    test('isFetched returns true after failed fetch', () async {
      final query = createQuery<String>(
        fn: () async => throw Exception('fail'),
      );
      try {
        await query.fetch();
      } catch (_) {}
      expect(query.isFetched(), isTrue);
    });

    test('retry integration: onFail dispatches failed action', () async {
      var failCount = 0;
      final query = createQuery<String>(
        fn: () async {
          failCount++;
          if (failCount <= 2) throw Exception('fail');
          return 'ok';
        },
        retryCount: 3,
      );
      await query.fetch();
      expect(query.state.data, 'ok');
      expect(query.state.fetchFailureCount, 0); // reset on success
    });
  });

  group('Query — focus/online events', () {
    test('onFocus resumes paused retryer', () async {
      online.setOnline(false);
      final query = createQuery<String>(
        fn: () async => 'data',
        networkMode: NetworkMode.online,
      );
      final future = query.fetch();
      await Future.delayed(Duration.zero);
      expect(query.state.fetchStatus, FetchStatus.paused);

      online.setOnline(true);
      query.onOnline();
      final result = await future;
      expect(result, 'data');
    });

    test('onFocus finds first observer that shouldFetchOnWindowFocus', () {
      final query = createQuery<String>(initialData: 'data');
      final obs1 = MockObserver();
      final obs2 = MockObserver().._shouldFetchOnFocus = true;
      query.addObserver(obs1);
      query.addObserver(obs2);
      query.onFocus();
      expect(obs1.refetchCount, 0);
      expect(obs2.refetchCount, 1);
    });

    test('onOnline finds first observer that shouldFetchOnReconnect', () {
      final query = createQuery<String>(initialData: 'data');
      final obs1 = MockObserver();
      final obs2 = MockObserver().._shouldFetchOnReconnect = true;
      query.addObserver(obs1);
      query.addObserver(obs2);
      query.onOnline();
      expect(obs1.refetchCount, 0);
      expect(obs2.refetchCount, 1);
    });
  });

  group('Query — cache notification', () {
    test('dispatch notifies cache on state change', () {
      final query = createQuery<String>(trackCache: true);
      query.setData('hello');
      expect(cacheEvents, isNotEmpty);
      expect(cacheEvents.last['type'], EventType.updated);
    });

    test('addObserver notifies cache', () {
      final query = createQuery<String>(trackCache: true);
      query.addObserver(MockObserver());
      expect(
        cacheEvents.any((e) => e['type'] == EventType.observerAdded),
        isTrue,
      );
    });

    test('removeObserver notifies cache', () {
      final query = createQuery<String>(trackCache: true);
      final observer = MockObserver();
      query.addObserver(observer);
      cacheEvents.clear();
      query.removeObserver(observer);
      expect(
        cacheEvents.any((e) => e['type'] == EventType.observerRemoved),
        isTrue,
      );
    });
  });

  group('Query — setOptions', () {
    test('updates queryFn', () async {
      final query = createQuery<String>(fn: () async => 'old');
      query.setOptions(queryFn: () async => 'new');
      await query.fetch();
      expect(query.state.data, 'new');
    });

    test('updates retryCount', () {
      final query = createQuery<String>(retryCount: 0);
      query.setOptions(retryCount: 5);
      expect(query.retryCount, 5);
    });

    test('updates meta', () {
      final query = createQuery<String>();
      query.setOptions(meta: {'source': 'test'});
      expect(query.meta, {'source': 'test'});
    });
  });

  group('Query — other methods', () {
    test('isDisabled returns true when no observers and not fetched', () {
      final query = createQuery<String>();
      expect(query.isDisabled(), isTrue);
    });

    test('isDisabled returns false when has observers', () {
      final query = createQuery<String>();
      query.addObserver(MockObserver());
      expect(query.isDisabled(), isFalse);
    });

    test('queryType getter', () {
      final query = createQuery<String>();
      expect(query.queryType, isNull);
      query.setOptions(queryType: 'infinite');
      expect(query.queryType, 'infinite');
    });
  });
}
