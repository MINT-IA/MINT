// Sub-phase 01.5 W02-T04 — R5 Runtime Kill Switch (Codex release-blocker).
//
// Tests for the `FeatureFlags.enableCoachHardGate` flag — declaration,
// default value, applyFromMap wire-up, and observable Sentry warning
// when the flag is disabled via server override.
//
// Per plan 01.5-02-04 task 1 behaviors:
//   * default true at cold start
//   * applyFromMap({'enableCoachHardGate': false}) flips to false
//   * applyFromMap({}) keeps default true
//   * true → false transition emits an observable warning hook

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/feature_flags.dart';

void main() {
  setUp(() {
    // Reset to default before each test — static state leakage guard
    // (same pattern as feature_flags_test.dart).
    FeatureFlags.enableCoachHardGate = true;
    FeatureFlags.debugCoachHardGateWarningHook = null;
  });

  tearDown(() {
    FeatureFlags.enableCoachHardGate = true;
    FeatureFlags.debugCoachHardGateWarningHook = null;
  });

  group('FeatureFlags.enableCoachHardGate — default value', () {
    test('default is true (gate active by cold start, R5 design contract)',
        () {
      // Cold-start invariant — shipping with default=false would defeat
      // the entire 01.5 phase per plan 02-04 objective.
      expect(FeatureFlags.enableCoachHardGate, isTrue);
    });
  });

  group('FeatureFlags.applyFromMap — enableCoachHardGate wire-up', () {
    test('applyFromMap({enableCoachHardGate: false}) flips to false', () {
      FeatureFlags.applyFromMap({'enableCoachHardGate': false});
      expect(FeatureFlags.enableCoachHardGate, isFalse);
    });

    test('applyFromMap({}) keeps default value (true) when key absent', () {
      FeatureFlags.applyFromMap({});
      expect(FeatureFlags.enableCoachHardGate, isTrue);
    });

    test('true → false transition emits an observable warning hook', () {
      // Plan 02-04 T-01.5-42 mitigation: rollback is auditable via
      // Sentry warning. We expose a test-only hook to assert the side
      // effect without mocking sentry_flutter.
      final captured = <String>[];
      FeatureFlags.debugCoachHardGateWarningHook = captured.add;

      FeatureFlags.applyFromMap({'enableCoachHardGate': false});

      expect(captured, hasLength(1),
          reason: 'Exactly one warning emitted on the true→false flip');
      expect(captured.single, contains('enableCoachHardGate'));
      expect(captured.single.toLowerCase(), contains('disabled'));
    });

    test('false → false (no transition) does NOT emit a warning', () {
      // If the flag is already false (e.g. set in a previous refresh),
      // re-applying false should NOT spam Sentry on every 6-hour cycle.
      FeatureFlags.enableCoachHardGate = false;
      final captured = <String>[];
      FeatureFlags.debugCoachHardGateWarningHook = captured.add;

      FeatureFlags.applyFromMap({'enableCoachHardGate': false});

      expect(captured, isEmpty,
          reason: 'No transition → no warning (avoid Sentry spam)');
    });
  });
}
