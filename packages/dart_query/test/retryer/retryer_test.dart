import 'dart:async';
import 'package:test/test.dart';
import 'package:dart_query/src/retryer/retryer.dart';
import 'package:dart_query/src/core/cancelled_error.dart';
import 'package:dart_query/src/core/focus_manager.dart';
import 'package:dart_query/src/core/online_manager.dart';
import 'package:dart_query/src/models/types.dart';

void main() {
  late FocusManager focus;
  late OnlineManager online;

  setUp(() {
    focus = FocusManager();
    focus.setFocused(true);
    online = OnlineManager();
    online.setOnline(true);
  });

  Retryer<T> createRetryer<T>({
    required Future<T> Function() fn,
    int retryCount = 3,
    Duration Function(int) retryDelay = _zeroDelay,
    NetworkMode networkMode = NetworkMode.always,
    bool Function() canRun = _alwaysTrue,
    void Function(int, Object)? onFail,
    void Function()? onPause,
    void Function()? onContinue,
    void Function(Object)? onCancel,
  }) {
    return Retryer<T>(
      fn: fn,
      retryCount: retryCount,
      retryDelay: retryDelay,
      networkMode: networkMode,
      canRun: canRun,
      onFail: onFail,
      onPause: onPause,
      onContinue: onContinue,
      onCancel: onCancel,
      focusManager: focus,
      onlineManager: online,
    );
  }

  group('Retryer — success', () {
    test('resolves on first success', () async {
      final retryer = createRetryer<String>(fn: () async => 'hello');
      final result = await retryer.start();
      expect(result, 'hello');
    });

    test('resolves synchronous return value', () async {
      final retryer = createRetryer<int>(fn: () async => 42);
      expect(await retryer.start(), 42);
    });
  });

  group('Retryer — retry', () {
    test('retries on failure up to retryCount', () async {
      var attempts = 0;
      final retryer = createRetryer<String>(
        fn: () async {
          attempts++;
          if (attempts < 3) throw Exception('fail $attempts');
          return 'success';
        },
        retryCount: 3,
      );
      final result = await retryer.start();
      expect(result, 'success');
      expect(attempts, 3);
    });

    test('rejects after exhausting retries', () async {
      final retryer = createRetryer<String>(
        fn: () async => throw Exception('always fail'),
        retryCount: 2,
      );
      await expectLater(retryer.start(), throwsException);
    });

    test('retryCount 0 means no retries', () async {
      var attempts = 0;
      final retryer = createRetryer<String>(
        fn: () async {
          attempts++;
          throw Exception('fail');
        },
        retryCount: 0,
      );
      await expectLater(retryer.start(), throwsException);
      expect(attempts, 1);
    });

    test('onFail callback fires for each retry failure', () async {
      final failures = <int>[];
      var attempts = 0;
      final retryer = createRetryer<String>(
        fn: () async {
          attempts++;
          if (attempts <= 2) throw Exception('fail');
          return 'ok';
        },
        retryCount: 3,
        onFail: (count, _) => failures.add(count),
      );
      await retryer.start();
      expect(failures, [1, 2]);
    });

    test('retryCondition can prevent retries', () async {
      var attempts = 0;
      final retryer = Retryer<String>(
        fn: () async {
          attempts++;
          throw Exception('no retry');
        },
        retryCount: 5,
        retryDelay: _zeroDelay,
        retryCondition: (error) => false,
        networkMode: NetworkMode.always,
        canRun: _alwaysTrue,
        focusManager: focus,
        onlineManager: online,
      );
      await expectLater(retryer.start(), throwsException);
      expect(attempts, 1);
    });
  });

  group('Retryer — cancel', () {
    test('cancel rejects with CancelledError', () async {
      final completer = Completer<String>();
      final retryer = createRetryer<String>(
        fn: () => completer.future,
      );
      final future = retryer.start();
      retryer.cancel();
      await expectLater(future, throwsA(isA<CancelledError>()));
    });

    test('cancel with revert flag', () async {
      final completer = Completer<String>();
      final retryer = createRetryer<String>(fn: () => completer.future);
      final future = retryer.start();
      retryer.cancel(revert: true);
      try {
        await future;
      } catch (e) {
        expect(e, isA<CancelledError>());
        expect((e as CancelledError).revert, isTrue);
      }
    });

    test('cancel with silent flag', () async {
      final completer = Completer<String>();
      final retryer = createRetryer<String>(fn: () => completer.future);
      final future = retryer.start();
      retryer.cancel(silent: true);
      try {
        await future;
      } catch (e) {
        expect((e as CancelledError).silent, isTrue);
      }
    });

    test('onCancel callback fires on cancel', () async {
      Object? cancelError;
      final completer = Completer<String>();
      final retryer = createRetryer<String>(
        fn: () => completer.future,
        onCancel: (error) => cancelError = error,
      );
      unawaited(retryer.start().catchError((_) => ''));
      retryer.cancel();
      expect(cancelError, isA<CancelledError>());
    });

    test('cancel after resolution is a no-op', () async {
      final retryer = createRetryer<String>(fn: () async => 'done');
      await retryer.start();
      retryer.cancel(); // should not throw
    });
  });

  group('Retryer — cancelRetry / continueRetry', () {
    test('cancelRetry stops retries but current attempt finishes', () async {
      var attempts = 0;
      final retryer = createRetryer<String>(
        fn: () async {
          attempts++;
          throw Exception('fail');
        },
        retryCount: 5,
      );
      retryer.cancelRetry();
      await expectLater(retryer.start(), throwsException);
      expect(attempts, 1);
    });

    test('continueRetry re-enables retries', () async {
      var attempts = 0;
      final retryer = createRetryer<String>(
        fn: () async {
          attempts++;
          if (attempts >= 3) return 'ok';
          throw Exception('fail');
        },
        retryCount: 5,
      );
      retryer.cancelRetry();
      retryer.continueRetry();
      final result = await retryer.start();
      expect(result, 'ok');
      expect(attempts, 3);
    });
  });

  group('Retryer — network modes', () {
    test('online mode: cannot start when offline', () async {
      online.setOnline(false);
      var started = false;
      final retryer = createRetryer<String>(
        fn: () async {
          started = true;
          return 'done';
        },
        networkMode: NetworkMode.online,
      );
      // Start returns a future that pauses immediately
      final future = retryer.start();
      await Future.delayed(Duration.zero);
      expect(started, isFalse);

      // Come back online
      online.setOnline(true);
      retryer.resume();
      final result = await future;
      expect(result, 'done');
      expect(started, isTrue);
    });

    test('always mode: starts even when offline', () async {
      online.setOnline(false);
      final retryer = createRetryer<String>(
        fn: () async => 'done',
        networkMode: NetworkMode.always,
      );
      final result = await retryer.start();
      expect(result, 'done');
    });
  });

  group('Retryer — pause/resume', () {
    test('pause and resume lifecycle', () async {
      var paused = false;
      var continued = false;
      online.setOnline(false);
      final retryer = createRetryer<String>(
        fn: () async => 'done',
        networkMode: NetworkMode.online,
        onPause: () => paused = true,
        onContinue: () => continued = true,
      );
      final future = retryer.start();
      await Future.delayed(Duration.zero);
      expect(paused, isTrue);

      online.setOnline(true);
      retryer.resume();
      await future;
      expect(continued, isTrue);
    });
  });

  group('Retryer — initialPromise', () {
    test('uses initialPromise on first attempt', () async {
      var fnCalled = false;
      final retryer = Retryer<String>(
        fn: () async {
          fnCalled = true;
          return 'from fn';
        },
        retryCount: 0,
        retryDelay: _zeroDelay,
        networkMode: NetworkMode.always,
        canRun: _alwaysTrue,
        initialPromise: Future.value('from initial'),
        focusManager: focus,
        onlineManager: online,
      );
      final result = await retryer.start();
      expect(result, 'from initial');
      expect(fnCalled, isFalse);
    });
  });
  group('Retryer — offlineFirst mode', () {
    test('starts first attempt when offline, pauses on retry', () async {
      online.setOnline(false);
      var attempts = 0;
      final retryer = createRetryer<String>(
        fn: () async {
          attempts++;
          if (attempts == 1) throw Exception('first fail');
          return 'ok';
        },
        retryCount: 3,
        networkMode: NetworkMode.offlineFirst,
      );
      final future = retryer.start();
      await Future.delayed(Duration.zero);
      expect(attempts, 1); // first attempt fired even offline

      // Come back online to allow retry
      online.setOnline(true);
      focus.setFocused(true);
      retryer.resume();
      final result = await future;
      expect(result, 'ok');
      expect(attempts, 2);
    });
  });

  group('Retryer — edge cases', () {
    test('double cancel is safe', () async {
      final completer = Completer<String>();
      final retryer = createRetryer<String>(fn: () => completer.future);
      unawaited(retryer.start().catchError((_) => ''));
      retryer.cancel();
      retryer.cancel(); // second cancel is a no-op
    });

    test('cancel during pause resolves pause and rejects', () async {
      online.setOnline(false);
      final retryer = createRetryer<String>(
        fn: () async => 'data',
        networkMode: NetworkMode.online,
      );
      final future = retryer.start();
      await Future.delayed(Duration.zero);
      retryer.cancel();
      await expectLater(future, throwsA(isA<CancelledError>()));
    });

    test('resume when not paused is a no-op', () {
      final retryer = createRetryer<String>(fn: () async => 'data');
      retryer.resume(); // no pause active, should not throw
    });

    test('retryDelay is called with correct failureCount', () async {
      final delays = <int>[];
      var attempts = 0;
      final retryer = createRetryer<String>(
        fn: () async {
          attempts++;
          if (attempts <= 2) throw Exception('fail');
          return 'ok';
        },
        retryCount: 3,
        retryDelay: (count) {
          delays.add(count);
          return Duration.zero;
        },
      );
      await retryer.start();
      expect(delays, [1, 2]);
    });

    test('initialPromise failure falls back to fn on retry', () async {
      var fnCalled = false;
      final retryer = Retryer<String>(
        fn: () async {
          fnCalled = true;
          return 'from fn';
        },
        retryCount: 1,
        retryDelay: _zeroDelay,
        networkMode: NetworkMode.always,
        canRun: _alwaysTrue,
        initialPromise: Future.error(Exception('initial fail')),
        focusManager: focus,
        onlineManager: online,
      );
      final result = await retryer.start();
      expect(result, 'from fn');
      expect(fnCalled, isTrue);
    });

    test('isAbortSignalConsumed tracks consumption', () {
      final retryer = createRetryer<String>(fn: () async => 'data');
      expect(retryer.isAbortSignalConsumed, isFalse);
      retryer.markAbortSignalConsumed();
      expect(retryer.isAbortSignalConsumed, isTrue);
    });
  });
}

Duration _zeroDelay(int _) => Duration.zero;
bool _alwaysTrue() => true;
