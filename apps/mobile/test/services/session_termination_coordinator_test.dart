import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/session_termination_coordinator.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SessionTerminationCoordinator', () {
    test('durable purge completes before one atomic memory clear phase',
        () async {
      final order = <String>[];
      final durableGate = Completer<void>();
      final coordinator = SessionTerminationCoordinator(
        clearAuthTokens: () async => order.add('tokens'),
        purgeDurableSessionData: () async {
          order.add('durable:start');
          await durableGate.future;
          order.add('durable:end');
        },
        purgeRemainingLocalData: () async => order.add('remaining'),
        clearSessionMemory: [
          () => order.add('coach-memory'),
          () => order.add('plan-memory'),
        ],
      );
      addTearDown(coordinator.dispose);

      final termination = coordinator.terminate();
      await Future<void>.delayed(Duration.zero);

      expect(order, ['durable:start']);
      expect(coordinator.isBlocked, isTrue);

      durableGate.complete();
      await termination;

      expect(order, [
        'durable:start',
        'durable:end',
        'remaining',
        'coach-memory',
        'plan-memory',
        'tokens',
      ]);
      expect(coordinator.isBlocked, isFalse);
    });

    test('writes marker and cancels notifications before any purge', () async {
      final order = <String>[];
      var marker = false;
      final coordinator = SessionTerminationCoordinator(
        sessionEpoch: SessionEpoch(),
        readTerminationPending: () async => marker,
        writeTerminationPending: () async {
          marker = true;
          order.add('marker:write');
        },
        clearTerminationPending: () async {
          marker = false;
          order.add('marker:clear');
        },
        cancelNotifications: () async => order.add('notifications'),
        clearAuthTokens: () async => order.add('tokens'),
        clearAuthRecoveryRequired: () async => order.add('recovery:clear'),
        purgeDurableSessionData: () async => order.add('durable'),
        purgeRemainingLocalData: () async => order.add('remaining'),
        clearSessionMemory: [() => order.add('memory')],
      );
      addTearDown(coordinator.dispose);

      await coordinator.terminate();

      expect(order, [
        'marker:write',
        'notifications',
        'durable',
        'remaining',
        'memory',
        'tokens',
        'marker:clear',
        'recovery:clear',
      ]);
      expect(marker, isFalse);
    });

    test('purge failure keeps marker and tokens then cold retry resumes',
        () async {
      var marker = false;
      var fail = true;
      var tokenClears = 0;
      var memoryClears = 0;

      SessionTerminationCoordinator build() => SessionTerminationCoordinator(
            sessionEpoch: SessionEpoch(),
            readTerminationPending: () async => marker,
            writeTerminationPending: () async => marker = true,
            clearTerminationPending: () async => marker = false,
            cancelNotifications: () async {},
            clearAuthTokens: () async => tokenClears++,
            purgeDurableSessionData: () async {
              if (fail) throw StateError('synthetic purge failure');
            },
            purgeRemainingLocalData: () async {},
            clearSessionMemory: [() => memoryClears++],
          );

      final first = build();
      await expectLater(first.terminate(), throwsStateError);
      first.dispose();
      expect(marker, isTrue);
      expect(tokenClears, 0);
      expect(memoryClears, 0);

      fail = false;
      final restarted = build();
      addTearDown(restarted.dispose);
      expect(await restarted.resumePendingTerminationIfNeeded(), isTrue);
      expect(marker, isFalse);
      expect(tokenClears, 1);
      expect(memoryClears, 1);
    });

    test('notification cancellation failure is fail closed', () async {
      var marker = false;
      var durableCalls = 0;
      var tokenClears = 0;
      final coordinator = SessionTerminationCoordinator(
        sessionEpoch: SessionEpoch(),
        readTerminationPending: () async => marker,
        writeTerminationPending: () async => marker = true,
        clearTerminationPending: () async => marker = false,
        cancelNotifications: () async {
          throw StateError('synthetic notification cancellation failure');
        },
        clearAuthTokens: () async => tokenClears++,
        purgeDurableSessionData: () async => durableCalls++,
        purgeRemainingLocalData: () async {},
        clearSessionMemory: const [],
      );
      addTearDown(coordinator.dispose);

      await expectLater(coordinator.terminate(), throwsStateError);

      expect(marker, isTrue);
      expect(durableCalls, 0);
      expect(tokenClears, 0);
      expect(coordinator.isBlocked, isTrue);
    });

    test('two terminal 401s and explicit logout share one transaction',
        () async {
      final gate = Completer<void>();
      var durableCalls = 0;
      var memoryCalls = 0;
      final coordinator = SessionTerminationCoordinator(
        clearAuthTokens: () async {},
        purgeDurableSessionData: () async {
          durableCalls++;
          await gate.future;
        },
        purgeRemainingLocalData: () async {},
        clearSessionMemory: [() => memoryCalls++],
      );
      addTearDown(coordinator.dispose);

      final first401 = coordinator.terminate();
      final second401 = coordinator.terminate();
      final explicitLogout = coordinator.terminate();
      await Future<void>.delayed(Duration.zero);

      expect(durableCalls, 1);
      gate.complete();
      await Future.wait([first401, second401, explicitLogout]);
      expect(durableCalls, 1);
      expect(memoryCalls, 1);
    });

    test('purge failure keeps memory untouched and coordinator fail closed',
        () async {
      var memoryCalls = 0;
      final coordinator = SessionTerminationCoordinator(
        clearAuthTokens: () async {},
        purgeDurableSessionData: () async {
          throw StateError('synthetic authority purge failure');
        },
        purgeRemainingLocalData: () async {},
        clearSessionMemory: [() => memoryCalls++],
      );
      addTearDown(coordinator.dispose);

      await expectLater(coordinator.terminate(), throwsStateError);

      expect(coordinator.isBlocked, isTrue);
      expect(memoryCalls, 0);
    });

    test('dispose during purge never calls provider memory callbacks',
        () async {
      final gate = Completer<void>();
      var memoryCalls = 0;
      final coordinator = SessionTerminationCoordinator(
        clearAuthTokens: () async {},
        purgeDurableSessionData: () => gate.future,
        purgeRemainingLocalData: () async {},
        clearSessionMemory: [() => memoryCalls++],
      );

      final termination = coordinator.terminate();
      await Future<void>.delayed(Duration.zero);
      coordinator.dispose();
      gate.complete();

      await expectLater(termination, throwsStateError);
      expect(memoryCalls, 0);
    });

    test(
        'awaits MintState cache deletion before session success and new cache write',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mint_precomputed_insight_v1', 'old-account-cache');
      final epoch = SessionEpoch();
      final mintState = MintStateProvider(sessionEpoch: epoch);
      addTearDown(mintState.dispose);
      final cacheDeleteGate = Completer<void>();
      var credentialsCleared = false;
      final coordinator = SessionTerminationCoordinator(
        sessionEpoch: epoch,
        clearAuthTokens: () async => credentialsCleared = true,
        purgeDurableSessionData: () async {},
        purgeRemainingLocalData: () async {},
        clearSessionMemory: [
          () async {
            await cacheDeleteGate.future;
            await mintState.clear();
          },
        ],
      );
      addTearDown(coordinator.dispose);

      final termination = coordinator.terminate();
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.isBlocked, isTrue);
      expect(credentialsCleared, isFalse);
      expect(
          prefs.getString('mint_precomputed_insight_v1'), 'old-account-cache');

      // A new-account recompute cannot cross the blocked epoch while the old
      // account cache deletion is still pending.
      await mintState.recompute(
        CoachProfile(
          birthYear: 1982,
          canton: 'VS',
          salaireBrutMensuel: 5583,
          goalA: GoalA(
            type: GoalAType.retraite,
            targetDate: DateTime(2042),
            label: 'Retraite',
          ),
        ),
      );
      expect(
          prefs.getString('mint_precomputed_insight_v1'), 'old-account-cache');

      cacheDeleteGate.complete();
      await termination;
      expect(credentialsCleared, isTrue);
      expect(prefs.getString('mint_precomputed_insight_v1'), isNull);

      // Only after the transaction reopens the epoch may a new session write
      // its cache; no delayed old clear remains able to erase it.
      await mintState.recompute(
        CoachProfile(
          birthYear: 1977,
          canton: 'VS',
          salaireBrutMensuel: 10184,
          goalA: GoalA(
            type: GoalAType.retraite,
            targetDate: DateTime(2042),
            label: 'Retraite',
          ),
        ),
      );
      expect(prefs.getString('mint_precomputed_insight_v1'), isNotNull);
    });
  });
}
