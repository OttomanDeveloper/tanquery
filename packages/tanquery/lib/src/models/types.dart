enum QueryStatus { pending, success, error }

enum FetchStatus { fetching, paused, idle }

enum MutationStatus { idle, pending, success, error }

enum NetworkMode { online, always, offlineFirst }

enum RefetchMode { reset, append, replace }

enum QueryActionType { fetch, success, error, invalidate, pause, resume, failed, setState }

enum MutationActionType { pending, success, error, failed, pause, resume }

enum EventType {
  added,
  removed,
  updated,
  observerAdded,
  observerRemoved,
}

enum QueryTypeFilter { all, active, inactive }

class StaleTime {
  final Duration? duration;
  final bool isStatic;

  const StaleTime._(this.duration, this.isStatic);

  factory StaleTime(Duration duration) => StaleTime._(duration, false);
  static const StaleTime static_ = StaleTime._(null, true);
}
