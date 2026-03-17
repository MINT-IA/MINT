import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/feature_flags.dart';

void main() {
  // Reset flags to known defaults before each test.
  setUp(() {
    FeatureFlags.enableSlmNarratives = true;
    FeatureFlags.valeurLocative2028Reform = false;
    FeatureFlags.enableDecisionScaffold = true;
    FeatureFlags.enableCouplePlusTier = true;
    FeatureFlags.slmPluginReady = false;
    FeatureFlags.safeModeDegraded = false;
    FeatureFlags.enableCoachPhase2 = true;
    FeatureFlags.enableLifeEventScreens = true;
    FeatureFlags.enableAdvancedSimulators = true;
    FeatureFlags.enableMortgageTools = true;
    FeatureFlags.enableIndependantTools = true;
    FeatureFlags.enableOpenBanking = false;
    FeatureFlags.enableAdminScreens = false;
  });

  // ---------------------------------------------------------------------------
  // Default values
  // ---------------------------------------------------------------------------
  group('FeatureFlags — defaults', () {
    test('SLM narratives enabled by default', () {
      expect(FeatureFlags.enableSlmNarratives, isTrue);
    });

    test('valeurLocative2028Reform off by default (legislation pending)', () {
      expect(FeatureFlags.valeurLocative2028Reform, isFalse);
    });

    test('decision scaffold enabled by default', () {
      expect(FeatureFlags.enableDecisionScaffold, isTrue);
    });

    test('couple plus tier enabled by default', () {
      expect(FeatureFlags.enableCouplePlusTier, isTrue);
    });

    test('SLM plugin not ready by default', () {
      expect(FeatureFlags.slmPluginReady, isFalse);
    });

    test('safe mode degraded off by default', () {
      expect(FeatureFlags.safeModeDegraded, isFalse);
    });

    test('open banking disabled by default', () {
      expect(FeatureFlags.enableOpenBanking, isFalse);
    });

    test('admin screens disabled by default', () {
      expect(FeatureFlags.enableAdminScreens, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // applyFromMap — gate open/close conditions
  // ---------------------------------------------------------------------------
  group('FeatureFlags — applyFromMap', () {
    test('enables a disabled flag', () {
      FeatureFlags.enableOpenBanking = false;
      FeatureFlags.applyFromMap({'enableOpenBanking': true});
      expect(FeatureFlags.enableOpenBanking, isTrue);
    });

    test('disables an enabled flag', () {
      FeatureFlags.enableSlmNarratives = true;
      FeatureFlags.applyFromMap({'enableSlmNarratives': false});
      expect(FeatureFlags.enableSlmNarratives, isFalse);
    });

    test('ignores unknown keys without crashing', () {
      FeatureFlags.applyFromMap({
        'unknownFlag': true,
        'anotherUnknown': 42,
      });
      // No exception thrown, existing flags unchanged
      expect(FeatureFlags.enableSlmNarratives, isTrue);
    });

    test('applies multiple flags at once', () {
      FeatureFlags.applyFromMap({
        'enableCouplePlusTier': false,
        'enableDecisionScaffold': false,
        'enableAdminScreens': true,
        'safeModeDegraded': true,
      });
      expect(FeatureFlags.enableCouplePlusTier, isFalse);
      expect(FeatureFlags.enableDecisionScaffold, isFalse);
      expect(FeatureFlags.enableAdminScreens, isTrue);
      expect(FeatureFlags.safeModeDegraded, isTrue);
    });

    test('non-boolean values treated as false', () {
      FeatureFlags.enableSlmNarratives = true;
      FeatureFlags.applyFromMap({'enableSlmNarratives': 'yes'});
      // 'yes' == true is false in Dart
      expect(FeatureFlags.enableSlmNarratives, isFalse);
    });

    test('null value in map treated as false', () {
      FeatureFlags.enableCouplePlusTier = true;
      FeatureFlags.applyFromMap({'enableCouplePlusTier': null});
      expect(FeatureFlags.enableCouplePlusTier, isFalse);
    });

    test('empty map does not change any flags', () {
      FeatureFlags.applyFromMap({});
      expect(FeatureFlags.enableSlmNarratives, isTrue);
      expect(FeatureFlags.valeurLocative2028Reform, isFalse);
      expect(FeatureFlags.enableOpenBanking, isFalse);
    });

    test('valeurLocative2028Reform can be toggled on', () {
      FeatureFlags.applyFromMap({'valeurLocative2028Reform': true});
      expect(FeatureFlags.valeurLocative2028Reform, isTrue);
    });

    test('all V1 screen gating flags respond to server config', () {
      FeatureFlags.applyFromMap({
        'enableCoachPhase2': false,
        'enableLifeEventScreens': false,
        'enableAdvancedSimulators': false,
        'enableMortgageTools': false,
        'enableIndependantTools': false,
      });
      expect(FeatureFlags.enableCoachPhase2, isFalse);
      expect(FeatureFlags.enableLifeEventScreens, isFalse);
      expect(FeatureFlags.enableAdvancedSimulators, isFalse);
      expect(FeatureFlags.enableMortgageTools, isFalse);
      expect(FeatureFlags.enableIndependantTools, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Gate logic scenarios
  // ---------------------------------------------------------------------------
  group('FeatureFlags — gate logic scenarios', () {
    test('SLM narratives gate: flag on + plugin ready = narratives available', () {
      FeatureFlags.enableSlmNarratives = true;
      FeatureFlags.slmPluginReady = true;
      FeatureFlags.safeModeDegraded = false;
      // Simulating the gate logic used in the app:
      final canUseSlm = FeatureFlags.enableSlmNarratives &&
          FeatureFlags.slmPluginReady &&
          !FeatureFlags.safeModeDegraded;
      expect(canUseSlm, isTrue);
    });

    test('SLM gate: flag on but plugin not ready = no narratives', () {
      FeatureFlags.enableSlmNarratives = true;
      FeatureFlags.slmPluginReady = false;
      final canUseSlm =
          FeatureFlags.enableSlmNarratives && FeatureFlags.slmPluginReady;
      expect(canUseSlm, isFalse);
    });

    test('SLM gate: safe mode degraded overrides everything', () {
      FeatureFlags.enableSlmNarratives = true;
      FeatureFlags.slmPluginReady = true;
      FeatureFlags.safeModeDegraded = true;
      final canUseSlm = FeatureFlags.enableSlmNarratives &&
          FeatureFlags.slmPluginReady &&
          !FeatureFlags.safeModeDegraded;
      expect(canUseSlm, isFalse);
    });
  });
}
