import 'dart:async';
import '../models/types.dart';
import '../query/query.dart';

typedef StreamFn<TChunk> = Stream<TChunk> Function();
typedef StreamReducer<TData, TChunk> = TData Function(TData accumulated, TChunk chunk);

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
