import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';
import 'package:tanquery/src/query/query.dart';
import 'package:tanquery/src/query/query_cache.dart';
import 'package:tanquery/src/query/query_observer.dart';
import 'package:tanquery/src/models/query_key.dart';
import 'package:tanquery/src/models/types.dart';
import 'package:tanquery/src/core/notify_manager.dart';
import 'package:tanquery/src/core/focus_manager.dart';
import 'package:tanquery/src/core/online_manager.dart';

void main() {
  late NotifyManager notify;
  late FocusManager focus;
  late OnlineManager online;
  late QueryCache cache;

  setUp(() {
    notify = NotifyManager();
    notify.setScheduler((cb) => cb());
    focus = FocusManager()..setFocused(true);
    online = OnlineManager()..setOnline(true);
    cache = QueryCache(notifyManager: notify);
  });

  QueryObserver<T> createObserver<T>({
    required QueryKey queryKey,
    required Future<T> Function() queryFn,
    Duration staleTime = Duration.zero,
    Duration gcTime = const Duration(minutes: 5),
    bool enabled = true,
    T? placeholderData,
    T? Function(T? previousData, Query? previousQuery)? placeholderDataFn,
    T Function(T data)? select,
    Duration? refetchInterval,
    int retryCount = 0,
    NetworkMode networkMode = NetworkMode.always,
  }) {
    return QueryObserver<T>(
      cache: cache,
      queryKey: queryKey,
      queryFn: queryFn,
      staleTime: staleTime,
      gcTime: gcTime,
      enabled: enabled,
      placeholderData: placeholderData,
      placeholderDataFn: placeholderDataFn,
      select: select,
      refetchInterval: refetchInterval,
      retryCount: retryCount,
      networkMode: networkMode,
      notifyManager: notify,
      focusManager: focus,
    );
  }

  group('QueryObserver — subscription lifecycle', () {
    test('fetches on first subscribe when no data', () async {
      final observer = createObserver<String>(
        queryKey: QueryKey(['test']),
        queryFn: () async => 'hello',
      );
      final states = <QueryObserverResult<String>>[];
      observer.subscribe((result) => states.add(result as QueryObserverResult<String>));
      await Future.delayed(Duration.zero);
      expect(states.any((s) => s.data == 'hello'), isTrue);
    });

    test('does not fetch when enabled=false', () async {
      var fetched = false;
      final observer = createObserver<String>(
        queryKey: QueryKey(['test_disabled']),
        queryFn: () async {
          fetched = true;
          return 'data';
        },
        enabled: false,
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(fetched, isFalse);
    });

    test('unsubscribe removes observer from query', () async {
      final observer = createObserver<String>(
        queryKey: QueryKey(['test_unsub']),
        queryFn: () async => 'data',
      );
      final unsub = observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      unsub();
      final query = cache.find(queryKey: QueryKey(['test_unsub']));
      expect(query?.observerCount, 0);
    });

    test('does not fetch when data exists and is fresh', () async {
      cache.build<String>(
        queryKey: QueryKey(['fresh']),
        queryFn: () async => 'cached',
        initialData: 'cached',
      );
      var fetchCount = 0;
      final observer = createObserver<String>(
        queryKey: QueryKey(['fresh']),
        queryFn: () async {
          fetchCount++;
          return 'new';
        },
        staleTime: const Duration(hours: 1),
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(fetchCount, 0);
      expect(observer.currentResult.data, 'cached');
    });

    test('fetches when data exists but is stale', () async {
      cache.build<String>(
        queryKey: QueryKey(['stale_fetch']),
        queryFn: () async => 'old',
        initialData: 'old',
      );
      var fetchCount = 0;
      final observer = createObserver<String>(
        queryKey: QueryKey(['stale_fetch']),
        queryFn: () async {
          fetchCount++;
          return 'new';
        },
        staleTime: Duration.zero,
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(fetchCount, 1);
    });
  });

  group('QueryObserver — result computation', () {
    test('isLoading when pending + fetching', () async {
      final completer = Completer<String>();
      final observer = createObserver<String>(
        queryKey: QueryKey(['loading']),
        queryFn: () => completer.future,
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(observer.currentResult.isLoading, isTrue);
      expect(observer.currentResult.isFetching, isTrue);
      completer.complete('done');
      await Future.delayed(Duration.zero);
      expect(observer.currentResult.isLoading, isFalse);
      expect(observer.currentResult.isSuccess, isTrue);
    });

    test('provides data after successful fetch', () async {
      final observer = createObserver<String>(
        queryKey: QueryKey(['success']),
        queryFn: () async => 'result',
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(observer.currentResult.data, 'result');
      expect(observer.currentResult.status, QueryStatus.success);
    });

    test('provides error after failed fetch', () async {
      final observer = createObserver<String>(
        queryKey: QueryKey(['error']),
        queryFn: () async => throw Exception('fail'),
        retryCount: 0,
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(observer.currentResult.isError, isTrue);
      expect(observer.currentResult.error, isA<Exception>());
    });

    test('isFetching during background refetch with existing data', () async {
      cache.build<String>(
        queryKey: QueryKey(['bg']),
        queryFn: () async => 'cached',
        initialData: 'cached',
      );
      final completer = Completer<String>();
      final observer = createObserver<String>(
        queryKey: QueryKey(['bg']),
        queryFn: () => completer.future,
        staleTime: Duration.zero,
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(observer.currentResult.data, 'cached');
      expect(observer.currentResult.isFetching, isTrue);
      expect(observer.currentResult.isLoading, isFalse);
      completer.complete('fresh');
      await Future.delayed(Duration.zero);
      expect(observer.currentResult.data, 'fresh');
    });
  });

  group('QueryObserver — placeholderData', () {
    test('shows placeholder while loading', () async {
      final completer = Completer<String>();
      final observer = createObserver<String>(
        queryKey: QueryKey(['ph']),
        queryFn: () => completer.future,
        placeholderData: 'placeholder',
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(observer.currentResult.data, 'placeholder');
      expect(observer.currentResult.isPlaceholderData, isTrue);
      expect(observer.currentResult.status, QueryStatus.success);

      completer.complete('real');
      await Future.delayed(Duration.zero);
      expect(observer.currentResult.data, 'real');
      expect(observer.currentResult.isPlaceholderData, isFalse);
    });

    test('placeholderData function receives previous data', () async {
      String? receivedPrev;
      final observer = createObserver<String>(
        queryKey: QueryKey(['ph_fn']),
        queryFn: () async => 'data',
        placeholderDataFn: (prev, prevQuery) {
          receivedPrev = prev;
          return 'from_fn';
        },
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(receivedPrev, isNull);
    });
  });

  group('QueryObserver — select', () {
    test('transforms data through select function', () async {
      final observer = createObserver<int>(
        queryKey: QueryKey(['sel']),
        queryFn: () async => 42,
        select: (data) => data * 2,
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(observer.currentResult.data, 84);
    });

    test('select memoizes when data reference unchanged', () async {
      var selectCount = 0;
      final observer = createObserver<String>(
        queryKey: QueryKey(['memo']),
        queryFn: () async => 'data',
        select: (data) {
          selectCount++;
          return data.toUpperCase();
        },
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      final count1 = selectCount;
      observer.updateResult();
      expect(selectCount, count1);
    });
  });

  group('QueryObserver — stale timer', () {
    test('data with expired staleTime is stale', () async {
      cache.build<String>(
        queryKey: QueryKey(['stale_timer']),
        queryFn: () async => 'data',
        initialData: 'data',
        initialDataUpdatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      // Use Completer so refetch stays pending — data stays stale
      final completer = Completer<String>();
      final observer = createObserver<String>(
        queryKey: QueryKey(['stale_timer']),
        queryFn: () => completer.future,
        staleTime: const Duration(seconds: 30),
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      // Data is 1 minute old, staleTime is 30s, fetch is pending → stale
      expect(observer.currentResult.isStale, isTrue);
      expect(observer.currentResult.isFetching, isTrue);
      completer.complete('fresh');
    });

    test('fresh data is not stale', () async {
      cache.build<String>(
        queryKey: QueryKey(['fresh_timer']),
        queryFn: () async => 'data',
        initialData: 'data',
        // dataUpdatedAt defaults to now → fresh
      );
      final observer = createObserver<String>(
        queryKey: QueryKey(['fresh_timer']),
        queryFn: () async => 'data',
        staleTime: const Duration(hours: 1),
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(observer.currentResult.isStale, isFalse);
    });
  });

  group('QueryObserver — refetch', () {
    test('refetch triggers new fetch', () async {
      var fetchCount = 0;
      final observer = createObserver<String>(
        queryKey: QueryKey(['rf']),
        queryFn: () async {
          fetchCount++;
          return 'data_$fetchCount';
        },
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(fetchCount, 1);

      await observer.refetch();
      expect(fetchCount, 2);
      expect(observer.currentResult.data, 'data_2');
    });
  });

  group('QueryObserver — shouldFetchOnWindowFocus / shouldFetchOnReconnect', () {
    test('shouldFetchOnWindowFocus returns true when stale', () async {
      final observer = createObserver<String>(
        queryKey: QueryKey(['focus']),
        queryFn: () async => 'data',
        staleTime: Duration.zero,
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(observer.shouldFetchOnWindowFocus(), isTrue);
    });

    test('shouldFetchOnReconnect returns true when stale', () async {
      final observer = createObserver<String>(
        queryKey: QueryKey(['reconnect']),
        queryFn: () async => 'data',
        staleTime: Duration.zero,
      );
      observer.subscribe((_) {});
      await Future.delayed(Duration.zero);
      expect(observer.shouldFetchOnReconnect(), isTrue);
    });
  });

  group('QueryObserver — refetchInterval', () {
    test('periodically refetches', () {
      fakeAsync((async) {
        var fetchCount = 0;
        final observer = createObserver<String>(
          queryKey: QueryKey(['interval']),
          queryFn: () async {
            fetchCount++;
            return 'data_$fetchCount';
          },
          refetchInterval: const Duration(seconds: 10),
        );
        observer.subscribe((_) {});
        // Initial fetch
        async.elapse(Duration.zero);
        expect(fetchCount, 1);
        // After 10 seconds, should refetch
        async.elapse(const Duration(seconds: 10));
        expect(fetchCount, 2);
        // After another 10 seconds
        async.elapse(const Duration(seconds: 10));
        expect(fetchCount, 3);
        observer.destroy();
      });
    });
  });

  group('QueryObserver — destroy', () {
    test('cleans up timers and unregisters from query', () {
      final observer = createObserver<String>(
        queryKey: QueryKey(['destroy']),
        queryFn: () async => 'data',
      );
      observer.subscribe((_) {});
      observer.destroy();
    });
  });
}
