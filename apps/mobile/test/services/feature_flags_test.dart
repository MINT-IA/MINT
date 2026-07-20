import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/feature_flags.dart';

const _pillar3aFlagRuntimeContract = r'''
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/feature_flags.dart';

void main() {
  test('pillar 3a beneficiary flag is false and backend-inert', () {
    expect(FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled, isFalse);
    FeatureFlags.applyFromMap(const <String, dynamic>{
      'pillar3aBeneficiaryClauseReferenceEnabled': true,
    });
    expect(
      FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled,
      isFalse,
      reason: 'Backend configuration must not enable the local G1 path.',
    );

    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;
    FeatureFlags.applyFromMap(const <String, dynamic>{
      'pillar3aBeneficiaryClauseReferenceEnabled': false,
    });
    expect(
      FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled,
      isTrue,
      reason: 'Backend configuration must not disable a local test opt-in.',
    );
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
  });
}
''';

Future<ProcessResult> _runPillar3aFlagRuntimeContract() async {
  final directory = await Directory.systemTemp.createTemp(
    'mint-pillar3a-flag-contract-',
  );
  final generated = File(
    '${directory.path}/pillar3a_flag_generated_test.dart',
  );
  try {
    await generated.writeAsString(_pillar3aFlagRuntimeContract, flush: true);
    return await Process.run(
      'flutter',
      <String>['test', generated.path, '--reporter', 'expanded'],
      workingDirectory: Directory.current.path,
    );
  } finally {
    await directory.delete(recursive: true);
  }
}

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
    FeatureFlags.enableGuidedSequences = false;
    FeatureFlags.financialPlanSetupEnabled = const bool.fromEnvironment(
      'MINT_TEST_FINANCIAL_PLAN_SETUP',
      defaultValue: false,
    );
    FeatureFlags.successionEvidenceCollectionEnabled = false;
    addTearDown(
      () => FeatureFlags.successionEvidenceCollectionEnabled = false,
    );
    // F7: enableCoachPhase2, enableLifeEventScreens, enableAdvancedSimulators,
    //     enableMortgageTools, enableIndependantTools removed (always true, no consumers)
    FeatureFlags.enableOpenBanking = false;
    FeatureFlags.enableAdminScreens = false;
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
    FeatureFlags.lppRegulationReferenceEnabled = false;
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
    addTearDown(() => FeatureFlags.enableGuidedSequences = false);
    addTearDown(() => FeatureFlags.financialPlanSetupEnabled = false);
    addTearDown(() => FeatureFlags.typedLppEvidence = false);
    addTearDown(() => FeatureFlags.documentLppEvidenceEnabled = false);
    addTearDown(() => FeatureFlags.lppRegulationReferenceEnabled = false);
    addTearDown(() => FeatureFlags.lppCapitalNoticeDeadlineEnabled = false);
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

    test('enableGuidedSequences is false by default', () {
      expect(FeatureFlags.enableGuidedSequences, isFalse);
    });

    test('financial plan setup remains false without the test-only opt-in', () {
      expect(FeatureFlags.financialPlanSetupEnabled, isFalse);
    });

    test('succession evidence collection is default-off and backend-inert', () {
      expect(FeatureFlags.successionEvidenceCollectionEnabled, isFalse);
      FeatureFlags.applyFromMap(const <String, dynamic>{
        'successionEvidenceCollectionEnabled': true,
      });
      expect(FeatureFlags.successionEvidenceCollectionEnabled, isFalse);
    });

    test('capital notice acquisition remains default-off', () {
      expect(FeatureFlags.lppCapitalNoticeAcquisitionEnabled, isFalse);
    });

    test(
      'pillar 3a beneficiary reference remains local-only and default-off',
      () async {
        final source =
            File('lib/services/feature_flags.dart').readAsStringSync();
        final violations = <String>[];
        if (!source.contains(
          'static bool pillar3aBeneficiaryClauseReferenceEnabled = false;',
        )) {
          violations.add('Missing explicit default-off production flag.');
        }
        final applyFromMapStart = source.indexOf('static void applyFromMap');
        final applyFromMapEnd = source.indexOf(
          'static Future<void> refreshFromBackend',
          applyFromMapStart,
        );
        final applyFromMap = source.substring(
          applyFromMapStart,
          applyFromMapEnd,
        );
        if (applyFromMap
            .contains('pillar3aBeneficiaryClauseReferenceEnabled')) {
          violations.add('Backend applyFromMap can mutate the local G1 flag.');
        }

        final result = await _runPillar3aFlagRuntimeContract();
        if (result.exitCode != 0) {
          violations.add(
            'Runtime default/inertia contract failed.\n'
            'stdout:\n${result.stdout}\n'
            'stderr:\n${result.stderr}',
          );
        }
        expect(
          violations,
          isEmpty,
          reason: violations.join('\n---\n'),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
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

    test('guided sequences remain local-only', () {
      FeatureFlags.enableGuidedSequences = true;
      FeatureFlags.applyFromMap({'enableGuidedSequences': false});
      expect(FeatureFlags.enableGuidedSequences, isTrue);
    });

    test('financial plan setup remains local-only', () {
      FeatureFlags.financialPlanSetupEnabled = true;
      FeatureFlags.applyFromMap({'financialPlanSetupEnabled': false});
      expect(FeatureFlags.financialPlanSetupEnabled, isTrue);
    });

    test('capital notice acquisition remains local-only and needs four flags',
        () {
      final switches = <void Function()>[
        () => FeatureFlags.typedLppEvidence = false,
        () => FeatureFlags.documentLppEvidenceEnabled = false,
        () => FeatureFlags.lppRegulationReferenceEnabled = false,
        () => FeatureFlags.lppCapitalNoticeDeadlineEnabled = false,
      ];
      for (final disableOne in switches) {
        FeatureFlags.typedLppEvidence = true;
        FeatureFlags.documentLppEvidenceEnabled = true;
        FeatureFlags.lppRegulationReferenceEnabled = true;
        FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
        disableOne();
        expect(FeatureFlags.lppCapitalNoticeAcquisitionEnabled, isFalse);
      }

      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      FeatureFlags.lppRegulationReferenceEnabled = true;
      FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
      expect(FeatureFlags.lppCapitalNoticeAcquisitionEnabled, isTrue);

      FeatureFlags.applyFromMap(const <String, dynamic>{
        'typedLppEvidence': false,
        'documentLppEvidenceEnabled': false,
        'lppRegulationReferenceEnabled': false,
        'lppCapitalNoticeDeadlineEnabled': false,
        'lppCapitalNoticeAcquisitionEnabled': false,
      });
      expect(FeatureFlags.typedLppEvidence, isTrue);
      expect(FeatureFlags.documentLppEvidenceEnabled, isTrue);
      expect(FeatureFlags.lppRegulationReferenceEnabled, isTrue);
      expect(FeatureFlags.lppCapitalNoticeDeadlineEnabled, isTrue);
      expect(FeatureFlags.lppCapitalNoticeAcquisitionEnabled, isTrue);
    });
  });

  // F7: V1 screen gating flags group removed — flags were always true with no consumers.
}
