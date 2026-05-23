import 'dart:async';
import '../models/types.dart';
import '../query/query.dart';

/// Factory that opens a stream of chunks. Called each time the query executes.
typedef StreamFn<TChunk> = Stream<TChunk> Function();
/// Folds a new [TChunk] into the accumulated [TData]. Called once per
/// stream event, similar to `List.fold`.
typedef StreamReducer<TData, TChunk> = TData Function(TData accumulated, TChunk chunk);

/// Wraps a [Stream] as a [QueryFn] so it can be used with the query cache.
///
/// Consumes the stream returned by [streamFn], folding each chunk through
/// [reducer] starting from [initialValue]. The resulting future completes
/// when the stream closes.
///
/// [refetchMode] controls what happens on refetch:
///
/// - [RefetchMode.reset] -- starts fresh from [initialValue] every time.
///   Previous data is discarded.
/// - [RefetchMode.append] -- starts from the existing cached data (via
///   [getCurrentData]) so new chunks build on top of what was already
///   accumulated.
/// - [RefetchMode.replace] -- starts from [initialValue] like reset, but
///   does not call [onData] during accumulation. The cache only sees the
///   final result, which replaces the old data atomically.
///
/// [onData] is called after each chunk is reduced (except in replace mode),
/// letting you push intermediate results into the cache before the stream
/// finishes.
QueryFn<TData> streamedQuery<TChunk, TData>({
  required StreamFn<TChunk> streamFn,
  required StreamReducer<TData, TChunk> reducer,
  required TData initialValue,
  RefetchMode refetchMode = RefetchMode.reset,
  TData? Function()? getCurrentData,
  void Function(TData data)? onData,
}) {
  return () async {
    final existingData = getCurrentData?.call();
    final stream = streamFn();

    switch (refetchMode) {
      case RefetchMode.reset:
        var result = initialValue;
        await for (final chunk in stream) {
          result = reducer(result, chunk);
          onData?.call(result);
        }
        return result;

      case RefetchMode.append:
        var result = existingData ?? initialValue;
        await for (final chunk in stream) {
          result = reducer(result, chunk);
          onData?.call(result);
        }
        return result;

      case RefetchMode.replace:
        var result = initialValue;
        await for (final chunk in stream) {
          result = reducer(result, chunk);
        }
        return result;
    }
  };
}
