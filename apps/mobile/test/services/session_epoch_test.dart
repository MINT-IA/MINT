import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/session_epoch.dart';

void main() {
  group('SessionEpoch', () {
    test('termination invalidates an old operation synchronously', () {
      final epoch = SessionEpoch();
      final old = epoch.capture();

      epoch.beginTermination();

      expect(old.assertCurrent, throwsA(isA<SessionEpochInvalidated>()));
      expect(epoch.capture, throwsA(isA<SessionEpochInvalidated>()));
    });

    test('termination drains a persistence already admitted before purge',
        () async {
      final epoch = SessionEpoch();
      final old = epoch.capture();
      final gate = Completer<void>();
      final order = <String>[];

      final write = epoch.runGuardedPersistence(old, () async {
        order.add('write:start');
        await gate.future;
        order.add('write:end');
      });
      await Future<void>.delayed(Duration.zero);

      epoch.beginTermination();
      var drained = false;
      final drain = epoch.drainPersistence().then((_) => drained = true);
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);

      gate.complete();
      await Future.wait([write, drain]);
      expect(order, ['write:start', 'write:end']);
    });

    test('old delayed persistence is rejected after termination completes',
        () async {
      final epoch = SessionEpoch();
      final old = epoch.capture();
      epoch.beginTermination();
      await epoch.drainPersistence();
      epoch.completeTermination();

      var writes = 0;
      await expectLater(
        epoch.runGuardedPersistence(old, () async => writes++),
        throwsA(isA<SessionEpochInvalidated>()),
      );
      expect(writes, 0);
      expect(epoch.capture(), isA<SessionEpochGuard>());
    });
  });
}
