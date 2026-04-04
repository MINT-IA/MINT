import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/session_snapshot_service.dart';

void main() {
  group('SessionDelta', () {
    test('isSignificant when retirement delta >= 50', () {
      const delta = SessionDelta(
        confidenceDelta: 0,
        retirementIncomeDelta: -51,
        fhsDelta: 0,
        timeSinceLastVisit: Duration(days: 7),
        cause: 'inaction',
      );
      expect(delta.isSignificant, isTrue);
      expect(delta.cause, 'inaction');
    });

    test('not significant for small changes', () {
      const delta = SessionDelta(
        confidenceDelta: 1,
        retirementIncomeDelta: -20,
        fhsDelta: 0.5,
        timeSinceLastVisit: Duration(days: 1),
      );
      expect(delta.isSignificant, isFalse);
    });

    test('cause defaults to inaction', () {
      const delta = SessionDelta(
        confidenceDelta: 0,
        retirementIncomeDelta: 0,
        fhsDelta: 0,
        timeSinceLastVisit: Duration(days: 1),
      );
      expect(delta.cause, 'inaction');
    });

    test('cause can be user_action', () {
      const delta = SessionDelta(
        confidenceDelta: 5,
        retirementIncomeDelta: 340,
        fhsDelta: 2,
        timeSinceLastVisit: Duration(days: 3),
        cause: 'user_action',
      );
      expect(delta.cause, 'user_action');
      expect(delta.isSignificant, isTrue);
    });

    test('projected values present for inaction', () {
      const delta = SessionDelta(
        confidenceDelta: 0,
        retirementIncomeDelta: -47,
        fhsDelta: 0,
        timeSinceLastVisit: Duration(days: 12),
        cause: 'inaction',
        projected30d: -117.5,
        projected6m: -705.0,
      );
      expect(delta.projected30d, -117.5);
      expect(delta.projected6m, -705.0);
    });
  });
}
