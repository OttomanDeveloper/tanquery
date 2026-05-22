enum QueryStatus { pending, success, error }

enum FetchStatus { fetching, paused, idle }

enum MutationStatus { idle, pending, success, error }

enum NetworkMode { online, always, offlineFirst }

enum FetchDirection { forward, backward }

enum RefetchMode { reset, append, replace }

enum QueryActionType { fetch, success, error, invalidate, pause, resume, failed, setState }

enum MutationActionType { pending, success, error, failed, pause, resume }

enum EventType {
  added,
  removed,
  updated,
  observerAdded,
  observerRemoved,
  observerResultsUpdated,
  observerOptionsUpdated,
}

enum QueryTypeFilter { all, active, inactive }

class StaleTime {
  final Duration? duration;
  final bool isStatic;

  const StaleTime._(this.duration, this.isStatic);

  factory StaleTime(Duration duration) => StaleTime._(duration, false);
  static const StaleTime static_ = StaleTime._(null, true);
  static const StaleTime zero = StaleTime._(Duration.zero, false);

  bool get isZero => !isStatic && duration == Duration.zero;
}
