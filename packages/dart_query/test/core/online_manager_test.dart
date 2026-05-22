import 'package:test/test.dart';
import 'package:dart_query/src/core/online_manager.dart';

void main() {
  group('OnlineManager', () {
    late OnlineManager manager;

    setUp(() => manager = OnlineManager());

    test('defaults to online', () {
      expect(manager.isOnline(), isTrue);
    });

    test('setOnline changes state', () {
      manager.setOnline(false);
      expect(manager.isOnline(), isFalse);
    });

    test('notifies subscribers on change', () {
      final events = <bool>[];
      manager.subscribe((online) => events.add(online));
      manager.setOnline(false);
      manager.setOnline(true);
      expect(events, [false, true]);
    });

    test('does not notify when value unchanged', () {
      var callCount = 0;
      manager.subscribe((_) => callCount++);
      manager.setOnline(true);
      expect(callCount, 0);
    });
  });
}
