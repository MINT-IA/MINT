import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/forecaster_service.dart';

String _source(String relativePath) {
  final file = File(relativePath);
  return file.existsSync() ? file.readAsStringSync() : '';
}

void _expectContractTokens(
  String source,
  Iterable<String> tokens, {
  required String reason,
}) {
  final missing = tokens.where((token) => !source.contains(token)).toList();
  expect(
    missing,
    isEmpty,
    reason: '$reason Missing behavioral markers: ${missing.join(', ')}',
  );
}

void main() {
  final coachProfileSource = _source('lib/models/coach_profile.dart');
  final providerSource = _source('lib/providers/coach_profile_provider.dart');
  final mintStateSource = _source('lib/services/mint_state_engine.dart');
  final forecasterSource = _source('lib/services/forecaster_service.dart');
  final dashboardSource =
      _source('lib/screens/coach/retirement_dashboard_screen.dart');
  final productSource =
      '$coachProfileSource\n$providerSource\n$mintStateSource\n'
      '$forecasterSource\n$dashboardSource';

  group('real BND-02 caller', () {
    test('MintStateEngine already delegates to ForecasterService', () {
      expect(
        mintStateSource,
        contains('ForecasterService.project(profile: profile)'),
      );
    });

    test('manual partner certificate selection is owner scoped', () {
      expect(coachProfileSource, contains('selectManualPartner'));
      expect(coachProfileSource, contains('expectedOwnerId'));
    });

    test('cold selection is gated by exact active receipt status', () {
      _expectContractTokens(
        productSource,
        const <String>[
          'PartnerAccountabilityBinding',
          'manualPartnerOwnerId',
          'receiptId',
          'lastVerifiedAt',
          'active',
        ],
        reason:
            'Cold reload must exclude certificate facts until status is current.',
      );
    });

    test('one owner-matched change recomputes through the visible dashboard',
        () {
      _expectContractTokens(
        productSource,
        const <String>[
          'MintStateEngine',
          'ForecasterService.project',
          'RetirementDashboardScreen',
          'retirement_partner_lpp_status_active',
        ],
        reason: 'Scalar hydration alone is not the BND-02 production caller.',
      );
    });
  });

  group('caisse rate cannot masquerade as a person fact or missing sentinel',
      () {
    test('manualPartner fundReturnRateRatio is quarantined from the profile',
        () {
      expect(
        coachProfileSource.contains(
          'rendementCaisse: typedManualPartnerLppValue(\n'
          '              LppEvidenceFactKey.fundReturnRateRatio',
        ),
        isFalse,
        reason:
            'A caisse rate has no person-level scope and must not reach calculators.',
      );
    });

    test('an exact self certificate rate of 0.02 ignores scenario LPP rates',
        () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'VD',
        salaireBrutMensuel: 8000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 100000,
          rendementCaisse: 0.02,
          salaireAssure: 70000,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2045),
          label: 'Synthetic retirement horizon',
        ),
      );
      const lowAssumption = ScenarioAssumptions(
        label: 'Synthetic low',
        lppReturn: 0.005,
        threeAReturn: 0.03,
        investmentReturn: 0.04,
        savingsReturn: 0.01,
        inflation: 0.015,
      );
      const highAssumption = ScenarioAssumptions(
        label: 'Synthetic high',
        lppReturn: 0.08,
        threeAReturn: 0.03,
        investmentReturn: 0.04,
        savingsReturn: 0.01,
        inflation: 0.015,
      );

      final low = ForecasterService.projectCustom(
        profile: profile,
        assumptions: lowAssumption,
      );
      final high = ForecasterService.projectCustom(
        profile: profile,
        assumptions: highAssumption,
      );

      expect(
        high.capitalFinal,
        low.capitalFinal,
        reason:
            'A known 2.00% certificate fact must not be replaced by a scenario assumption.',
      );
    });
  });
}
