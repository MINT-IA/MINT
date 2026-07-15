import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:provider/provider.dart';

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

final class _OwnerMatchedProjectionProvider extends CoachProfileProvider {
  _OwnerMatchedProjectionProvider(this._value);

  static const ownerId = '22222222-2222-4222-8222-222222222222';
  CoachProfile _value;
  final binding = PartnerAccountabilityBinding(
    receiptId: '11111111-1111-4111-8111-111111111111',
    manualPartnerOwnerId: ownerId,
    state: PartnerAccountabilityBindingState.active,
    createdAt: DateTime.utc(2026, 7, 15),
    noticeVersion: 'notice-v1',
    policyVersion: 'policy-v1',
    privacyContact: 'privacy@example.test',
    rightsChannel: 'https://example.test/rights',
    lastVerifiedAt: DateTime.utc(2026, 7, 15),
    receiptCreatedAt: DateTime.utc(2026, 7, 15),
    expiresAt: DateTime.utc(2027, 7, 15),
  );

  @override
  CoachProfile get profile => _value;

  @override
  bool get hasProfile => true;

  @override
  bool get isLoaded => true;

  @override
  PartnerAccountabilityBinding get partnerLppAccountabilityBinding => binding;

  @override
  PartnerAccountabilityBindingState get partnerLppAccountabilityState =>
      binding.state;

  void replaceOwnerMatchedPartnerCapital({
    required String ownerId,
    required double value,
  }) {
    if (ownerId != binding.manualPartnerOwnerId) {
      throw StateError('Synthetic owner mismatch');
    }
    final partner = _value.conjoint!;
    _value = _value.copyWith(
      conjoint: partner.copyWith(
        prevoyance: partner.prevoyance!.copyWith(avoirLppTotal: value),
      ),
    );
    notifyListeners();
  }

  void notifySameProfile() => notifyListeners();
}

CoachProfile _projectionProfile() => CoachProfile(
      firstName: 'Julien',
      birthYear: 1985,
      canton: 'VD',
      etatCivil: CoachCivilStatus.marie,
      salaireBrutMensuel: 8000,
      prevoyance: const PrevoyanceProfile(avoirLppTotal: 120000),
      conjoint: const ConjointProfile(
        birthYear: 1987,
        salaireBrutMensuel: 5000,
        prevoyance: PrevoyanceProfile(avoirLppTotal: 60000),
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2050),
        label: 'Retraite',
      ),
    );

Widget _projectionHarness(
  CoachProfileProvider provider,
  ProjectionResult Function(CoachProfile profile) projectionBuilder,
) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
        ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
        ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: RetirementDashboardScreen(
          projectionBuilder: projectionBuilder,
        ),
      ),
    );

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

    testWidgets(
        'one owner-matched change projects once and updates visible capital',
        (tester) async {
      final provider = _OwnerMatchedProjectionProvider(_projectionProfile());
      var projectionCalls = 0;
      ProjectionResult project(CoachProfile profile) {
        projectionCalls += 1;
        return ForecasterService.project(profile: profile);
      }

      await tester.pumpWidget(_projectionHarness(provider, project));
      await tester.pump();
      expect(projectionCalls, 1);
      final before = tester
          .widget<Text>(
            find.byKey(const Key('retirement_capital_amount')),
          )
          .data;

      provider.replaceOwnerMatchedPartnerCapital(
        ownerId: _OwnerMatchedProjectionProvider.ownerId,
        value: 150000,
      );
      await tester.pump();

      expect(projectionCalls, 2);
      final after = tester
          .widget<Text>(
            find.byKey(const Key('retirement_capital_amount')),
          )
          .data;
      expect(after, isNot(before));

      await tester.pump();
      provider.notifySameProfile();
      await tester.pump();
      expect(projectionCalls, 2);
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

    test('legacy serialized 0.02 remains an assumption without known marker',
        () {
      final legacyPrevoyance = PrevoyanceProfile.fromJson({
        'avoirLppTotal': 100000,
        'rendementCaisse': 0.02,
        'salaireAssure': 70000,
      });
      expect(legacyPrevoyance.rendementCaisse, 0.02);
      expect(legacyPrevoyance.rendementCaisseConnu, isFalse);
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'VD',
        salaireBrutMensuel: 8000,
        prevoyance: legacyPrevoyance,
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
        greaterThan(low.capitalFinal),
        reason: 'The historical 2% sentinel must not freeze scenario returns.',
      );
      final explicitRoundTrip = PrevoyanceProfile.fromJson(
        const PrevoyanceProfile(
          rendementCaisse: 0.02,
          salaireAssure: 70000,
        ).toJson(),
      );
      expect(explicitRoundTrip.rendementCaisseConnu, isTrue);
    });
  });
}
