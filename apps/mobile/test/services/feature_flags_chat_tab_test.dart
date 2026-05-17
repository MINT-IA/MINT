// Phase 96 D-01 + D-21 — FeatureFlags.chatTabVisible tests.
//
// Validates the kill-switch for the chat tab in MintShell.NavigationBar.
// Default is true (4-tab nav unchanged) until D-11 staging baseline-pull
// authorises the flip. Server override flows through applyFromMap().

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/feature_flags.dart';

void main() {
  group('FeatureFlags.chatTabVisible', () {
    setUp(() {
      // Reset to default before each test — static field state would otherwise
      // leak across tests inside the same isolate.
      FeatureFlags.chatTabVisible = true;
    });

    test('defaults to true (D-21 baseline — flip deferred to staging soak)', () {
      expect(FeatureFlags.chatTabVisible, isTrue);
    });

    test('applyFromMap({chatTabVisible: false}) flips the flag to false', () {
      FeatureFlags.applyFromMap(<String, dynamic>{'chatTabVisible': false});
      expect(FeatureFlags.chatTabVisible, isFalse);
    });

    test(
      'applyFromMap with non-boolean value coerces to false (defensive)',
      () {
        FeatureFlags.applyFromMap(
          <String, dynamic>{'chatTabVisible': 'not_a_bool'},
        );
        expect(FeatureFlags.chatTabVisible, isFalse);
      },
    );

    test('applyFromMap without chatTabVisible key leaves flag untouched', () {
      FeatureFlags.chatTabVisible = false;
      FeatureFlags.applyFromMap(<String, dynamic>{
        'enableCouplePlusTier': true,
      });
      expect(FeatureFlags.chatTabVisible, isFalse);
    });
  });
}
