import 'package:test/test.dart';
import 'package:dart_query/src/models/query_state.dart';
import 'package:dart_query/src/models/types.dart';

void main() {
  group('QueryState', () {
    test('default state is pending + idle', () {
      final state = QueryState<String>();
      expect(state.status, QueryStatus.pending);
      expect(state.fetchStatus, FetchStatus.idle);
      expect(state.data, isNull);
      expect(state.error, isNull);
      expect(state.isInvalidated, isFalse);
    });

    test('isLoading requires pending + fetching', () {
      final state = QueryState<String>(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.fetching,
      );
      expect(state.isLoading, isTrue);
      expect(state.isFetching, isTrue);
      expect(state.isPending, isTrue);
    });

    test('isFetching is true during background refetch', () {
      final state = QueryState<String>(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.fetching,
        data: 'cached',
      );
      expect(state.isLoading, isFalse);
      expect(state.isFetching, isTrue);
      expect(state.isSuccess, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      final state = QueryState<String>(
        status: QueryStatus.success,
        data: 'hello',
        dataUpdateCount: 1,
      );
      final updated = state.copyWith(fetchStatus: FetchStatus.fetching);
      expect(updated.data, 'hello');
      expect(updated.status, QueryStatus.success);
      expect(updated.fetchStatus, FetchStatus.fetching);
      expect(updated.dataUpdateCount, 1);
    });

    test('copyWith can set nullable fields to null', () {
      final state = QueryState<String>(data: 'hello', error: 'err');
      final cleared = state.copyWith(data: () => null, error: () => null);
      expect(cleared.data, isNull);
      expect(cleared.error, isNull);
    });

    test('isPaused when fetchStatus is paused', () {
      final state = QueryState<String>(fetchStatus: FetchStatus.paused);
      expect(state.isPaused, isTrue);
    });
  });
}
