import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/account_session_bootstrap.dart';
import 'package:mint_mobile/services/session_epoch.dart';

void main() {
  test(
      'epoch change during auth resolution coalesces listeners and initializes each authority once',
      () async {
    final epoch = SessionEpoch();
    final auth = ChangeNotifier();
    addTearDown(auth.dispose);
    var authReady = false;
    var resolveCalls = 0;
    final calls = <String, int>{};
    final bootstrap = AccountSessionBootstrap(
      sessionEpoch: epoch,
      resolveInitialAuth: () async {
        resolveCalls++;
        if (!authReady) {
          epoch.beginTermination();
          epoch.completeTermination();
          authReady = true;
          auth.notifyListeners();
        }
      },
      isAuthReady: () => authReady,
      isAuthenticated: () => true,
      initializers: [
        for (final edge in const [
          ('local', false),
          ('subscription', true),
          ('household', true),
          ('timeline', true),
        ])
          AccountSessionInitializer(
            edge.$1,
            (_) async => calls.update(
              edge.$1,
              (value) => value + 1,
              ifAbsent: () => 1,
            ),
            requiresAuthentication: edge.$2,
          ),
      ],
    );
    addTearDown(bootstrap.dispose);
    bootstrap.bindAuth(auth);

    await Future.wait([bootstrap.start(), bootstrap.start()]);
    await bootstrap.start();

    expect(resolveCalls, 1);
    expect(calls, {
      'local': 1,
      'subscription': 1,
      'household': 1,
      'timeline': 1,
    });

    epoch.beginTermination();
    epoch.completeTermination();
    await Future.wait([bootstrap.start(), bootstrap.start()]);

    expect(resolveCalls, 2);
    expect(calls, {
      'local': 2,
      'subscription': 2,
      'household': 2,
      'timeline': 2,
    });
  });

  test('cold termination decision globally precedes every account initializer',
      () async {
    final epoch = SessionEpoch();
    final authDecision = Completer<void>();
    final calls = <String>[];
    final bootstrap = AccountSessionBootstrap(
      sessionEpoch: epoch,
      resolveInitialAuth: () async {
        calls.add('auth:start');
        await authDecision.future;
        calls.add('auth:ready');
      },
      isAuthReady: () => true,
      isAuthenticated: () => true,
      initializers: [
        for (final name in const [
          'coach',
          'budget',
          'biography',
          'subscription',
          'timeline',
          'document',
          'household',
          'byok',
          'scan',
        ])
          AccountSessionInitializer(
            name,
            (_) async => calls.add(name),
          ),
      ],
    );

    final start = bootstrap.start();
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['auth:start']);

    authDecision.complete();
    await start;
    expect(calls, [
      'auth:start',
      'auth:ready',
      'coach',
      'budget',
      'biography',
      'subscription',
      'timeline',
      'document',
      'household',
      'byok',
      'scan',
    ]);
  });

  test('failed auth readiness publishes no account initialization', () async {
    final calls = <String>[];
    final bootstrap = AccountSessionBootstrap(
      sessionEpoch: SessionEpoch(),
      resolveInitialAuth: () async {},
      isAuthReady: () => false,
      isAuthenticated: () => false,
      initializers: [
        AccountSessionInitializer('coach', (_) async => calls.add('coach')),
      ],
    );

    await bootstrap.start();
    expect(calls, isEmpty);
  });

  test('a slow endpoint cannot starve an independent same-stage provider',
      () async {
    final slowEndpoint = Completer<void>();
    final calls = <String>[];
    final bootstrap = AccountSessionBootstrap(
      sessionEpoch: SessionEpoch(),
      resolveInitialAuth: () async {},
      isAuthReady: () => true,
      isAuthenticated: () => true,
      initializers: [
        AccountSessionInitializer('subscription', (_) async {
          calls.add('subscription:start');
          await slowEndpoint.future;
        }),
        AccountSessionInitializer(
          'financialPlan',
          (_) async => calls.add('financialPlan'),
        ),
      ],
    );

    final start = bootstrap.start();
    await Future<void>.delayed(Duration.zero);

    expect(calls, ['subscription:start', 'financialPlan']);
    slowEndpoint.complete();
    await start;
  });

  test('old bootstrap cannot continue initializers after epoch invalidation',
      () async {
    final epoch = SessionEpoch();
    final first = Completer<void>();
    final calls = <String>[];
    final bootstrap = AccountSessionBootstrap(
      sessionEpoch: epoch,
      resolveInitialAuth: () async {},
      isAuthReady: () => true,
      isAuthenticated: () => true,
      initializers: [
        AccountSessionInitializer('coach', (_) async {
          calls.add('coach:start');
          await first.future;
        }),
        AccountSessionInitializer(
          'budget',
          (_) async => calls.add('budget'),
          stage: 1,
        ),
      ],
    );

    final start = bootstrap.start();
    await Future<void>.delayed(Duration.zero);
    epoch.beginTermination();
    first.complete();
    await start;

    expect(calls, ['coach:start']);
  });

  test(
      'anonymous local bootstrap initializes the ledger without authenticated network work',
      () async {
    var authenticated = false;
    final calls = <String>[];
    final bootstrap = AccountSessionBootstrap(
      sessionEpoch: SessionEpoch(),
      resolveInitialAuth: () async => calls.add('auth:anonymous'),
      isAuthReady: () => true,
      isAuthenticated: () => authenticated,
      initializers: [
        AccountSessionInitializer(
          'ledger',
          (_) async => calls.add('ledger:local'),
        ),
        AccountSessionInitializer(
          'subscription-network',
          (_) async => calls.add('subscription:network'),
          requiresAuthentication: true,
        ),
      ],
    );

    await bootstrap.start();

    expect(calls, ['auth:anonymous', 'ledger:local']);

    authenticated = true;
    bootstrap.retryAfterAuthChange();
    await bootstrap.start();

    expect(calls, [
      'auth:anonymous',
      'ledger:local',
      'subscription:network',
    ]);
  });

  test('auth flip during local in-flight queues authenticated initializers',
      () async {
    var authenticated = false;
    final localStarted = Completer<void>();
    final releaseLocal = Completer<void>();
    final calls = <String>[];
    final bootstrap = AccountSessionBootstrap(
      sessionEpoch: SessionEpoch(),
      resolveInitialAuth: () async {},
      isAuthReady: () => true,
      isAuthenticated: () => authenticated,
      initializers: [
        AccountSessionInitializer('ledger', (_) async {
          calls.add('ledger:local');
          localStarted.complete();
          await releaseLocal.future;
        }),
        AccountSessionInitializer(
          'subscription',
          (_) async => calls.add('subscription:authenticated'),
          requiresAuthentication: true,
        ),
        AccountSessionInitializer(
          'household',
          (_) async => calls.add('household:authenticated'),
          requiresAuthentication: true,
        ),
      ],
    );

    final local = bootstrap.start();
    await localStarted.future;
    authenticated = true;
    bootstrap.retryAfterAuthChange();
    final queued = bootstrap.start();
    releaseLocal.complete();
    await Future.wait([local, queued]);

    expect(calls, [
      'ledger:local',
      'subscription:authenticated',
      'household:authenticated',
    ]);
  });

  test('composition root classifies every backend bootstrap initializer', () {
    final source = File('lib/app.dart').readAsStringSync();

    for (final name in const [
      'subscription',
      'timelineAuthenticated',
      'household',
    ]) {
      expect(
        _initializerBlock(source, name),
        contains('requiresAuthentication: true'),
        reason: name,
      );
    }
    for (final name in const [
      'coach',
      'budget',
      'biography',
      'timelineLocal',
      'document',
      'byok',
      'scan',
      'financialPlan',
    ]) {
      expect(
        _initializerBlock(source, name),
        isNot(contains('requiresAuthentication: true')),
        reason: name,
      );
    }
    expect(
      _initializerBlock(source, 'timelineLocal'),
      contains('includeAuthenticatedNetwork: false'),
    );
  });
}

String _initializerBlock(String source, String name) {
  final marker = "'$name',";
  final bootstrapStart = source.indexOf('AccountSessionBootstrap(');
  final initializersStart = source.indexOf('initializers: [', bootstrapStart);
  final nameIndex = source.indexOf(marker, initializersStart);
  expect(nameIndex, greaterThanOrEqualTo(0), reason: name);
  final start = source.lastIndexOf('AccountSessionInitializer(', nameIndex);
  final next = source.indexOf('AccountSessionInitializer(', nameIndex + 1);
  return source.substring(start, next < 0 ? source.length : next);
}
