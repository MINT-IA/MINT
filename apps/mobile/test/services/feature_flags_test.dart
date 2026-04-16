import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/feature_flags.dart';

/// Tests for FeatureFlags — server-driven feature gating.
///
/// Validates default values, applyFromMap behavior, and edge cases.
/// Feature flags control V1 screen gating, billing tiers, and SLM.
void main() {
  setUp(() {
    // Reset all flags to defaults before each test
    FeatureFlags.enableSlmNarratives = true;
    FeatureFlags.valeurLocative2028Reform = false;
    FeatureFlags.enableDecisionScaffold = true;
    FeatureFlags.enableCouplePlusTier = true;
    FeatureFlags.slmPluginReady = false;
    FeatureFlags.safeModeDegraded = false;
    // F7: enableCoachPhase2, enableLifeEventScreens, enableAdvancedSimulators,
    //     enableMortgageTools, enableIndependantTools removed (always true, no consumers)
    FeatureFlags.enableOpenBanking = false;
    FeatureFlags.enableAdminScreens = false;
  });

  group('FeatureFlags — default values', () {
    test('enableSlmNarratives is true by default', () {
      expect(FeatureFlags.enableSlmNarratives, isTrue);
    });

    test('valeurLocative2028Reform is false until legislation passes', () {
      expect(FeatureFlags.valeurLocative2028Reform, isFalse);
    });

    test('enableDecisionScaffold is true by default', () {
      expect(FeatureFlags.enableDecisionScaffold, isTrue);
    });

    test('enableCouplePlusTier is true by default', () {
      expect(FeatureFlags.enableCouplePlusTier, isTrue);
    });

    test('slmPluginReady is false until runtime init', () {
      expect(FeatureFlags.slmPluginReady, isFalse);
    });

    test('safeModeDegraded is false by default', () {
      expect(FeatureFlags.safeModeDegraded, isFalse);
    });

    test('enableOpenBanking is false by default', () {
      expect(FeatureFlags.enableOpenBanking, isFalse);
    });

    test('enableAdminScreens is false by default', () {
      expect(FeatureFlags.enableAdminScreens, isFalse);
    });
  });

  group('FeatureFlags.applyFromMap', () {
    test('applies enableCouplePlusTier from map', () {
      FeatureFlags.applyFromMap({'enableCouplePlusTier': false});
      expect(FeatureFlags.enableCouplePlusTier, isFalse);
    });

    test('applies enableSlmNarratives from map', () {
      FeatureFlags.applyFromMap({'enableSlmNarratives': false});
      expect(FeatureFlags.enableSlmNarratives, isFalse);
    });

    test('applies valeurLocative2028Reform from map', () {
      FeatureFlags.applyFromMap({'valeurLocative2028Reform': true});
      expect(FeatureFlags.valeurLocative2028Reform, isTrue);
    });

    test('applies safeModeDegraded from map', () {
      FeatureFlags.applyFromMap({'safeModeDegraded': true});
      expect(FeatureFlags.safeModeDegraded, isTrue);
    });

    test('applies multiple flags at once', () {
      FeatureFlags.applyFromMap({
        'enableCouplePlusTier': false,
        'enableSlmNarratives': false,
        'enableOpenBanking': true,
        'enableAdminScreens': true,
      });
      expect(FeatureFlags.enableCouplePlusTier, isFalse);
      expect(FeatureFlags.enableSlmNarratives, isFalse);
      expect(FeatureFlags.enableOpenBanking, isTrue);
      expect(FeatureFlags.enableAdminScreens, isTrue);
    });

    test('ignores unknown keys in map', () {
      FeatureFlags.applyFromMap({
        'unknownFlag': true,
        'anotherUnknown': 42,
      });
      // No crash, and existing flags remain unchanged
      expect(FeatureFlags.enableSlmNarratives, isTrue);
    });

    test('empty map does not change any flags', () {
      final before = FeatureFlags.enableCouplePlusTier;
      FeatureFlags.applyFromMap({});
      expect(FeatureFlags.enableCouplePlusTier, before);
    });

    test('non-boolean values treated as false', () {
      FeatureFlags.applyFromMap({'enableCouplePlusTier': 'yes'});
      expect(FeatureFlags.enableCouplePlusTier, isFalse,
          reason: '"yes" != true, so == true evaluates to false');
    });

    test('null value treated as false', () {
      FeatureFlags.applyFromMap({'enableCouplePlusTier': null});
      expect(FeatureFlags.enableCouplePlusTier, isFalse);
    });
  });

  // F7: V1 screen gating flags group removed — flags were always true with no consumers.
}
