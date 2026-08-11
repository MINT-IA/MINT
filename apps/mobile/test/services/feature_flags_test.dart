import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/e2e_runtime_flags.dart';
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
    FeatureFlags.enableMint2FirstExperienceEntry = false;
    FeatureFlags.enableMintNext3aProductHandoff = false;
    FeatureFlags.enableMintNextHousing = false;
    FeatureFlags.debugBackendFetcher = null;
    FeatureFlags.debugBackendRefreshTimeout = null;
    E2eRuntimeFlags.resetForTest();
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
    test('debug-only housing harness opens the same product gate', () {
      expect(FeatureFlags.enableMintNextHousing, isFalse);
      E2eRuntimeFlags.mintNextHousingOverride = true;
      FeatureFlags.applyRuntimeOverrides();
      expect(FeatureFlags.enableMintNextHousing, isTrue);
      expect(FeatureFlags.mintNextHousingListenable.value, isTrue);

      FeatureFlags.applyFromMap({'enableMintNextHousing': false});
      FeatureFlags.applyRuntimeOverrides();
      expect(FeatureFlags.enableMintNextHousing, isTrue);
      expect(FeatureFlags.mintNextHousingListenable.value, isTrue);

      E2eRuntimeFlags.resetForTest();
      FeatureFlags.enableMintNextHousing = false;
      expect(FeatureFlags.enableMintNextHousing, isFalse);
      expect(FeatureFlags.mintNextHousingListenable.value, isFalse);
    });

    test('keeps Mint Next housing default-off and accepts only true', () {
      expect(FeatureFlags.enableMintNextHousing, isFalse);
      FeatureFlags.applyFromMap({'enableMintNextHousing': true});
      expect(FeatureFlags.enableMintNextHousing, isTrue);
      FeatureFlags.applyFromMap({'enableMintNextHousing': 'true'});
      expect(FeatureFlags.enableMintNextHousing, isFalse);
    });

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

  group('Mint Next 3a product handoff kill switch', () {
    test('debug harness may apply only its explicit bounded remote decision',
        () {
      E2eRuntimeFlags.mintNext3aRemoteFlagOverride = true;
      FeatureFlags.applyRuntimeOverrides();
      expect(FeatureFlags.enableMintNext3aProductHandoff, isFalse);

      E2eRuntimeFlags.mintNext3aHarnessOverride = true;
      FeatureFlags.applyRuntimeOverrides();
      expect(FeatureFlags.enableMintNext3aProductHandoff, isTrue);

      E2eRuntimeFlags.mintNext3aRemoteFlagOverride = false;
      FeatureFlags.applyRuntimeOverrides();
      expect(FeatureFlags.enableMintNext3aProductHandoff, isFalse);
    });

    test('debug harness reapplies its decision after backend refresh',
        () async {
      E2eRuntimeFlags.mintNext3aHarnessOverride = true;
      E2eRuntimeFlags.mintNext3aRemoteFlagOverride = true;
      FeatureFlags.debugBackendFetcher = () async => <String, dynamic>{};

      await FeatureFlags.refreshFromBackend();

      expect(FeatureFlags.enableMintNext3aProductHandoff, isTrue);
    });

    testWidgets('notifies rendered consumers before and after refresh',
        (tester) async {
      final response = Completer<Map<String, dynamic>>();
      FeatureFlags.enableMintNext3aProductHandoff = true;
      FeatureFlags.debugBackendFetcher = () => response.future;

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: FeatureFlags.mintNext3aProductHandoffListenable,
            builder: (_, enabled, __) => Text(enabled ? 'open' : 'closed'),
          ),
        ),
      );
      expect(find.text('open'), findsOneWidget);

      final refresh = FeatureFlags.refreshFromBackend();
      await tester.pump();
      expect(find.text('closed'), findsOneWidget);

      response.complete({'enableMintNext3aProductHandoff': true});
      await refresh;
      await tester.pump();
      expect(find.text('open'), findsOneWidget);
    });

    test('defaults off and accepts only exact boolean true', () {
      expect(FeatureFlags.enableMintNext3aProductHandoff, isFalse);

      FeatureFlags.applyFromMap({'enableMintNext3aProductHandoff': true});
      expect(FeatureFlags.enableMintNext3aProductHandoff, isTrue);

      for (final value in <Object?>['true', null, 1]) {
        FeatureFlags.applyFromMap({'enableMintNext3aProductHandoff': value});
        expect(FeatureFlags.enableMintNext3aProductHandoff, isFalse);
      }
    });

    test('refresh resets synchronously before awaiting backend', () async {
      FeatureFlags.enableMintNext3aProductHandoff = true;
      final response = Completer<Map<String, dynamic>>();
      FeatureFlags.debugBackendFetcher = () => response.future;

      final refresh = FeatureFlags.refreshFromBackend();
      expect(FeatureFlags.enableMintNext3aProductHandoff, isFalse);

      response.complete({'enableMintNext3aProductHandoff': true});
      await refresh;
      expect(FeatureFlags.enableMintNext3aProductHandoff, isTrue);
    });

    test('missing flag, timeout, and network failure remain closed', () async {
      FeatureFlags.enableMintNext3aProductHandoff = true;
      FeatureFlags.debugBackendFetcher = () async => <String, dynamic>{};
      await FeatureFlags.refreshFromBackend();
      expect(FeatureFlags.enableMintNext3aProductHandoff, isFalse);

      FeatureFlags.enableMintNext3aProductHandoff = true;
      FeatureFlags.debugBackendRefreshTimeout = Duration.zero;
      FeatureFlags.debugBackendFetcher = () async {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        return {'enableMintNext3aProductHandoff': true};
      };
      await FeatureFlags.refreshFromBackend();
      expect(FeatureFlags.enableMintNext3aProductHandoff, isFalse);

      FeatureFlags.enableMintNext3aProductHandoff = true;
      FeatureFlags.debugBackendRefreshTimeout = null;
      FeatureFlags.debugBackendFetcher =
          () => Future.error(Exception('offline'));
      await FeatureFlags.refreshFromBackend();
      expect(FeatureFlags.enableMintNext3aProductHandoff, isFalse);
    });

    test('an older successful refresh cannot resurrect the flag', () async {
      final older = Completer<Map<String, dynamic>>();
      FeatureFlags.debugBackendFetcher = () => older.future;
      final firstRefresh = FeatureFlags.refreshFromBackend();

      FeatureFlags.debugBackendFetcher =
          () => Future.error(Exception('offline'));
      await FeatureFlags.refreshFromBackend();
      older.complete({'enableMintNext3aProductHandoff': true});
      await firstRefresh;

      expect(FeatureFlags.enableMintNext3aProductHandoff, isFalse);
    });
  });

  // F7: V1 screen gating flags group removed — flags were always true with no consumers.
}
