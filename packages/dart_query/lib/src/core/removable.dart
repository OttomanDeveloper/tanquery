import 'dart:async';
import 'package:meta/meta.dart';

abstract class Removable {
  Duration gcTime;
  Timer? _gcTimer;

  Removable({required this.gcTime});

  void scheduleGc() {
    clearGcTimeout();
    _gcTimer = Timer(gcTime, () => optionalRemove());
  }

  void clearGcTimeout() {
    _gcTimer?.cancel();
    _gcTimer = null;
  }

  void updateGcTime(Duration? newGcTime) {
    final effective = newGcTime ?? const Duration(minutes: 5);
    if (effective > gcTime) gcTime = effective;
  }

  void destroy() {
    clearGcTimeout();
  }

  @protected
  void optionalRemove();
}
