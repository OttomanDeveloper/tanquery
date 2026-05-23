import 'dart:async';
import 'package:meta/meta.dart';

/// Base class for objects that can be garbage-collected after a timeout.
///
/// When nothing references the object, [scheduleGc] starts a timer.
/// After [gcTime] elapses, [optionalRemove] is called to clean up.
abstract class Removable {
  /// How long to wait before garbage-collecting this object.
  Duration gcTime;
  Timer? _gcTimer;

  /// Creates a removable with the given [gcTime].
  Removable({required this.gcTime});

  /// Starts the garbage collection timer. Cancels any existing timer first.
  void scheduleGc() {
    clearGcTimeout();
    _gcTimer = Timer(gcTime, () => optionalRemove());
  }

  /// Cancels the current garbage collection timer, if any.
  void clearGcTimeout() {
    _gcTimer?.cancel();
    _gcTimer = null;
  }

  /// Updates [gcTime] to [newGcTime], but only if the new value is longer.
  ///
  /// Defaults to 5 minutes when [newGcTime] is null.
  void updateGcTime(Duration? newGcTime) {
    final effective = newGcTime ?? const Duration(minutes: 5);
    if (effective > gcTime) gcTime = effective;
  }

  /// Cancels the GC timer and tears down this object.
  void destroy() {
    clearGcTimeout();
  }

  /// Called when the GC timer fires. Subclasses decide whether to remove themselves.
  @protected
  void optionalRemove();
}
