import 'package:test/test.dart';
import 'package:dart_query/src/core/focus_manager.dart';

void main() {
  group('FocusManager', () {
    late FocusManager manager;

    setUp(() => manager = FocusManager());

    test('defaults to focused', () {
      expect(manager.isFocused(), isTrue);
    });

    test('setFocused changes state', () {
      manager.setFocused(false);
      expect(manager.isFocused(), isFalse);
      manager.setFocused(true);
      expect(manager.isFocused(), isTrue);
    });

    test('notifies subscribers on change', () {
      final events = <bool>[];
      manager.subscribe((focused) => events.add(focused));
      manager.setFocused(false);
      manager.setFocused(true);
      expect(events, [false, true]);
    });

    test('does not notify when value unchanged', () {
      manager.setFocused(true); // initial set
      var callCount = 0;
      manager.subscribe((_) => callCount++);
      manager.setFocused(true); // same value again
      expect(callCount, 0);
    });
  });
}
