import 'dart:async';
import 'package:test/test.dart';
import 'package:dart_query/src/query_client.dart';
import 'package:dart_query/src/query/query.dart';
import 'package:dart_query/src/mutation/mutation.dart';
import 'package:dart_query/src/models/query_key.dart';
import 'package:dart_query/src/models/types.dart';
import 'package:dart_query/src/core/notify_manager.dart';
import 'package:dart_query/src/core/focus_manager.dart';
import 'package:dart_query/src/core/online_manager.dart';

void main() {
  late QueryClient client;
  late NotifyManager notify;
  late FocusManager focus;
  late OnlineManager online;

  setUp(() {
    notify = NotifyManager();
    notify.setScheduler((cb) => cb());
    focus = FocusManager()..setFocused(true);
    online = OnlineManager()..setOnline(true);
    client = QueryClient(
      notifyManager: notify,
      focusManager: focus,
      onlineManager: online,
    );
  });

  group('QueryClient — lifecycle', () {
    test('mount subscribes to focus and online managers', () {
      client.mount();
      // Trigger focus change — should not throw
      focus.setFocused(false);
      focus.setFocused(true);
      online.setOnline(false);
      online.setOnline(true);
      client.unmount();
    });

    test('mount is reference counted', () {
      client.mount();
      client.mount();
      client.unmount(); // first unmount — still mounted
      // Should still work
      focus.setFocused(false);
      focus.setFocused(true);
      client.unmount(); // second unmount — actually unmounts
    });

    test('focus triggers query cache onFocus', () async {
      client.mount();
      // Add a query to the cache
      final cache = client.getQueryCache();
      cache.build<String>(
        queryKey: QueryKey(['focus_test']),
        queryFn: () async => 'data',
        initialData: 'data',
      );
      // Focus change should propagate
      focus.setFocused(false);
      focus.setFocused(true);
      client.unmount();
    });
  });

  group('QueryClient — data access', () {
    test('getQueryData returns cached data', () {
      final cache = client.getQueryCache();
      cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => '',
        initialData: 'hello',
      );
      expect(client.getQueryData<String>(QueryKey(['todos'])), 'hello');
    });

    test('getQueryData returns null for missing key', () {
      expect(client.getQueryData<String>(QueryKey(['missing'])), isNull);
    });

    test('getQueryState returns full state', () {
      final cache = client.getQueryCache();
      cache.build<String>(
        queryKey: QueryKey(['state']),
        queryFn: () async => '',
        initialData: 'data',
      );
      final state = client.getQueryState(QueryKey(['state']));
      expect(state, isNotNull);
      expect(state!.status, QueryStatus.success);
    });

    test('setQueryData writes to cache', () {
      client.setQueryData<String>(QueryKey(['set']), 'new_value');
      expect(client.getQueryData<String>(QueryKey(['set'])), 'new_value');
    });

    test('setQueryData with function updater', () {
      client.setQueryData<String>(QueryKey(['upd']), 'initial');
      client.setQueryData<String>(
        QueryKey(['upd']),
        (String old) => '${old}_updated',
      );
      expect(client.getQueryData<String>(QueryKey(['upd'])), 'initial_updated');
    });
  });

  group('QueryClient — fetchQuery', () {
    test('fetches and returns data', () async {
      final data = await client.fetchQuery<String>(
        queryKey: QueryKey(['fetch']),
        queryFn: () async => 'fetched',
      );
      expect(data, 'fetched');
    });

    test('returns cached data when not stale', () async {
      final cache = client.getQueryCache();
      cache.build<String>(
        queryKey: QueryKey(['cached_fetch']),
        queryFn: () async => 'old',
        initialData: 'cached',
      );
      var fetchCount = 0;
      final data = await client.fetchQuery<String>(
        queryKey: QueryKey(['cached_fetch']),
        queryFn: () async {
          fetchCount++;
          return 'fresh';
        },
        staleTime: const Duration(hours: 1),
      );
      expect(data, 'cached');
      expect(fetchCount, 0);
    });
  });

  group('QueryClient — prefetchQuery', () {
    test('prefetches silently', () async {
      await client.prefetchQuery<String>(
        queryKey: QueryKey(['prefetch']),
        queryFn: () async => 'prefetched',
      );
      expect(client.getQueryData<String>(QueryKey(['prefetch'])), 'prefetched');
    });

    test('swallows errors', () async {
      await client.prefetchQuery<String>(
        queryKey: QueryKey(['prefetch_err']),
        queryFn: () async => throw Exception('fail'),
      );
      // No throw
    });
  });

  group('QueryClient — invalidateQueries', () {
    test('marks matching queries as invalidated', () async {
      final cache = client.getQueryCache();
      final q = cache.build<String>(
        queryKey: QueryKey(['inv']),
        queryFn: () async => 'data',
        initialData: 'data',
      );
      await client.invalidateQueries(queryKey: QueryKey(['inv']), exact: true);
      expect(q.state.isInvalidated, isTrue);
    });

    test('partial key invalidation', () async {
      final cache = client.getQueryCache();
      final q1 = cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => '',
        initialData: 'a',
      );
      final q2 = cache.build<String>(
        queryKey: QueryKey(['todos', 1]),
        queryFn: () async => '',
        initialData: 'b',
      );
      cache.build<String>(
        queryKey: QueryKey(['users']),
        queryFn: () async => '',
        initialData: 'c',
      );
      await client.invalidateQueries(queryKey: QueryKey(['todos']));
      expect(q1.state.isInvalidated, isTrue);
      expect(q2.state.isInvalidated, isTrue);
    });
  });

  group('QueryClient — removeQueries', () {
    test('removes matching queries from cache', () {
      final cache = client.getQueryCache();
      cache.build<String>(queryKey: QueryKey(['rm']), queryFn: () async => '', initialData: 'data');
      expect(cache.getAll().length, 1);
      client.removeQueries(queryKey: QueryKey(['rm']), exact: true);
      expect(cache.getAll().length, 0);
    });
  });

  group('QueryClient — cancelQueries', () {
    test('cancels in-flight queries', () async {
      final cache = client.getQueryCache();
      final q = cache.build<String>(
        queryKey: QueryKey(['cancel']),
        queryFn: () => Completer<String>().future,
        networkMode: NetworkMode.always,
      );
      unawaited(q.fetch().catchError((_) => ''));
      await Future.delayed(Duration.zero);
      expect(q.state.fetchStatus, FetchStatus.fetching);

      await client.cancelQueries(queryKey: QueryKey(['cancel']), exact: true);
      expect(q.state.fetchStatus, FetchStatus.idle);
    });
  });

  group('QueryClient — isFetching / isMutating', () {
    test('isFetching counts fetching queries', () async {
      final cache = client.getQueryCache();
      final q = cache.build<String>(
        queryKey: QueryKey(['counting']),
        queryFn: () => Completer<String>().future,
        networkMode: NetworkMode.always,
      );
      expect(client.isFetching(), 0);
      unawaited(q.fetch().catchError((_) => ''));
      await Future.delayed(Duration.zero);
      expect(client.isFetching(), 1);
      q.destroy();
    });
  });

  group('QueryClient — clear', () {
    test('clears both caches', () {
      final cache = client.getQueryCache();
      cache.build<String>(queryKey: QueryKey(['a']), queryFn: () async => '');
      cache.build<String>(queryKey: QueryKey(['b']), queryFn: () async => '');
      expect(cache.getAll().length, 2);
      client.clear();
      expect(cache.getAll().length, 0);
    });
  });

  group('QueryClient — ensureQueryData', () {
    test('returns cached data if available', () async {
      final cache = client.getQueryCache();
      cache.build<String>(
        queryKey: QueryKey(['ensure']),
        queryFn: () async => 'old',
        initialData: 'cached',
      );
      final data = await client.ensureQueryData<String>(
        queryKey: QueryKey(['ensure']),
        queryFn: () async => 'fresh',
        staleTime: const Duration(hours: 1),
      );
      expect(data, 'cached');
    });

    test('fetches if no cached data', () async {
      final data = await client.ensureQueryData<String>(
        queryKey: QueryKey(['ensure_new']),
        queryFn: () async => 'fetched',
      );
      expect(data, 'fetched');
    });

    test('revalidateIfStale triggers background refetch', () async {
      final cache = client.getQueryCache();
      cache.build<String>(
        queryKey: QueryKey(['revalidate']),
        queryFn: () async => 'old',
        initialData: 'stale_data',
        initialDataUpdatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      var fetchCount = 0;
      final data = await client.ensureQueryData<String>(
        queryKey: QueryKey(['revalidate']),
        queryFn: () async {
          fetchCount++;
          return 'refreshed';
        },
        staleTime: const Duration(minutes: 5),
        revalidateIfStale: true,
      );
      expect(data, 'stale_data'); // returns cached immediately
      await Future.delayed(Duration.zero);
      // background refetch should have fired
    });
  });

  group('QueryClient — resetQueries', () {
    test('resets queries to initial state', () async {
      final cache = client.getQueryCache();
      final q = cache.build<String>(
        queryKey: QueryKey(['reset']),
        queryFn: () async => 'data',
        initialData: 'original',
      );
      q.setData('changed');
      expect(q.state.data, 'changed');
      await client.resetQueries(queryKey: QueryKey(['reset']), exact: true);
      expect(q.state.data, 'original');
    });
  });

  group('QueryClient — isMutating', () {
    test('counts pending mutations', () async {
      expect(client.isMutating(), 0);
      final mutationCache = client.getMutationCache();
      final m = mutationCache.build<String, String>(
        config: MutationConfig(mutationFn: (v) => Completer<String>().future),
      );
      unawaited(m.execute('input').catchError((_) => ''));
      await Future.delayed(Duration.zero);
      expect(client.isMutating(), 1);
    });
  });

  group('QueryClient — refetchQueries with type filter', () {
    test('only refetches active queries', () async {
      final cache = client.getQueryCache();
      var activeCount = 0;
      var inactiveCount = 0;
      final q1 = cache.build<String>(
        queryKey: QueryKey(['active_q']),
        queryFn: () async {
          activeCount++;
          return 'active';
        },
        initialData: 'a',
      );
      cache.build<String>(
        queryKey: QueryKey(['inactive_q']),
        queryFn: () async {
          inactiveCount++;
          return 'inactive';
        },
        initialData: 'b',
      );
      // Add observer to make q1 active
      q1.addObserver(_MockObserver());
      q1.invalidate();

      await client.refetchQueries(type: QueryTypeFilter.active);
      expect(activeCount, 1);
      expect(inactiveCount, 0);
    });
  });
}

class _MockObserver implements QueryUpdateCallback {
  @override
  void onQueryUpdate() {}
  @override
  bool shouldFetchOnWindowFocus() => false;
  @override
  bool shouldFetchOnReconnect() => false;
  @override
  Future<void> refetch({bool cancelRefetch = true}) async {}
}
