import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/data_spine_snapshot.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/services/data_spine/data_spine_readiness_digest_service.dart';
import 'package:mint_mobile/services/data_spine/data_spine_service.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 5, 23, 12);

  CoachProfile buildProfile({
    PrevoyanceProfile prevoyance = const PrevoyanceProfile(
      anneesContribuees: 18,
      lacunesAVS: 2,
      renteAVSEstimeeMensuelle: 1800,
      avoirLppTotal: 50000,
      avoirLppObligatoire: 32000,
      avoirLppSurobligatoire: 18000,
      rachatMaximum: 25000,
      salaireAssure: 70000,
      nombre3a: 1,
      totalEpargne3a: 12000,
    ),
    Map<String, ProfileDataSource> dataSources = const {
      'prevoyance.avoirLppTotal': ProfileDataSource.certificate,
      'prevoyance.totalEpargne3a': ProfileDataSource.userInput,
      'plannedContributions.3a': ProfileDataSource.userInput,
      'depenses.loyer': ProfileDataSource.userInput,
      'depenses.assuranceMaladie': ProfileDataSource.userInput,
      'patrimoine.epargneLiquide': ProfileDataSource.userInput,
      'dettes.totalDettes': ProfileDataSource.userInput,
    },
    Map<String, DateTime> dataTimestamps = const {},
    List<PlannedMonthlyContribution> plannedContributions = const [
      PlannedMonthlyContribution(
        id: 'primary_3a',
        label: '3a',
        amount: 500,
        category: '3a',
        isAutomatic: true,
      ),
    ],
    GoalA? goal,
    double loyer = 2100,
  }) {
    return CoachProfile(
      firstName: 'Julien',
      birthYear: 1987,
      canton: 'VD',
      commune: 'Lausanne',
      salaireBrutMensuel: 8000,
      nombreDeMois: 13,
      employmentStatus: 'salarie',
      etatCivil: CoachCivilStatus.celibataire,
      depenses: DepensesProfile(
        loyer: loyer,
        assuranceMaladie: 430,
        transport: 120,
        telecom: 80,
      ),
      prevoyance: prevoyance,
      patrimoine: const PatrimoineProfile(
        epargneLiquide: 18000,
        investissements: 7000,
      ),
      dettes: const DetteProfile(
        creditConsommation: 3000,
        mensualiteCreditConso: 250,
      ),
      goalA: goal ??
          GoalA(
            type: GoalAType.retraite,
            targetDate: DateTime.utc(2052),
            label: 'Retraite',
          ),
      plannedContributions: plannedContributions,
      dataSources: dataSources,
      dataTimestamps: dataTimestamps,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 5, 1),
    );
  }

  group('DataSpineService', () {
    test('derives stable financial situation from CoachProfile', () {
      final spine = DataSpineService.fromProfile(buildProfile(), now: fixedNow);

      expect(spine.computedAt, fixedNow);
      expect(spine.situation.firstName.value, 'Julien');
      expect(spine.situation.birthYear.value, 1987);
      expect(spine.situation.canton.value, 'VD');
      expect(spine.situation.commune.value, 'Lausanne');
      expect(spine.situation.grossAnnualIncome.value, 104000);
      expect(spine.situation.monthlyHousingCost.value, 2100);
      expect(spine.situation.lamalPremiumMonthly.value, 430);
      expect(spine.situation.liquidSavings.value, 18000);
      expect(spine.situation.investments.value, 7000);
      expect(spine.situation.totalDebt.value, 3000);
    });

    test('does not promote untrusted profile defaults into situation facts',
        () {
      final profile = CoachProfile(
        birthYear: 1987,
        canton: 'VD',
        salaireBrutMensuel: 8000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime.utc(2052),
          label: 'Retraite',
        ),
        depenses: const DepensesProfile(
          loyer: 1500,
          assuranceMaladie: 420,
        ),
        patrimoine: const PatrimoineProfile(epargneLiquide: 12000),
        dettes: const DetteProfile(creditConsommation: 3000),
      );

      final spine = DataSpineService.fromProfile(profile, now: fixedNow);

      expect(spine.situation.monthlyHousingCost.hasValue, isFalse);
      expect(spine.situation.lamalPremiumMonthly.hasValue, isFalse);
      expect(spine.situation.liquidSavings.hasValue, isFalse);
      expect(spine.situation.totalDebt.hasValue, isFalse);
    });

    test('canonical situation answers clear the readiness situation gap', () {
      final beforeProfile = CoachProfile.fromWizardAnswers({
        'q_net_income_period_chf': 7200,
        'q_pay_frequency': 'monthly',
        'q_housing_cost_period_chf': 2200,
        'q_lamal_premium_monthly_chf': 420,
      });
      final beforeDigest = DataSpineReadinessDigestService.fromSpine(
        DataSpineService.fromProfile(beforeProfile, now: fixedNow),
      );

      expect(beforeDigest.missingDomains, contains('situation'));

      final afterProfile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1988,
        'q_canton': 'VD',
        'q_net_income_period_chf': 7200,
        'q_pay_frequency': 'monthly',
        'q_cash_total': 25000,
        'q_has_consumer_debt': 'yes',
        'q_debt_payments_period_chf': 350,
        'q_housing_cost_period_chf': 2200,
        'q_lamal_premium_monthly_chf': 420,
      });
      final afterSpine = DataSpineService.fromProfile(
        afterProfile,
        now: fixedNow,
      );
      final afterDigest = DataSpineReadinessDigestService.fromSpine(afterSpine);

      expect(afterSpine.situation.birthYear.value, 1988);
      expect(afterSpine.situation.canton.value, 'VD');
      expect(afterSpine.situation.liquidSavings.value, 25000);
      expect(afterSpine.situation.totalDebt.value, 8400);
      expect(afterSpine.situation.totalDebt.meta.source,
          ProfileDataSource.estimated);
      expect(afterSpine.situation.totalDebt.meta.confidence,
          FieldConfidence.estimated);
      expect(afterDigest.missingDomains, isNot(contains('situation')));
    });

    test(
        'does not treat CoachProfile budget defaults as explicit situation data',
        () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1988,
        'q_canton': 'VD',
        'q_net_income_period_chf': 7200,
        'q_pay_frequency': 'monthly',
        'q_cash_total': 25000,
        'q_has_consumer_debt': 'no',
        'q_debt_payments_period_chf': 0,
      });

      final spine = DataSpineService.fromProfile(profile, now: fixedNow);
      final digest = DataSpineReadinessDigestService.fromSpine(spine);

      expect(spine.situation.monthlyHousingCost.hasValue, isFalse);
      expect(spine.situation.lamalPremiumMonthly.hasValue, isFalse);
      expect(digest.missingDomains, contains('situation'));
    });

    test('explicit budget keys and zero debt clear the situation gap', () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1988,
        'q_canton': 'VD',
        'q_net_income_period_chf': 7200,
        'q_pay_frequency': 'monthly',
        'q_cash_total': 25000,
        'q_has_consumer_debt': 'no',
        'q_debt_payments_period_chf': 0,
        'q_housing_cost_period_chf': 2200,
        'q_lamal_premium_monthly_chf': 420,
      });

      final spine = DataSpineService.fromProfile(profile, now: fixedNow);
      final digest = DataSpineReadinessDigestService.fromSpine(spine);

      expect(spine.situation.monthlyHousingCost.value, 2200);
      expect(spine.situation.lamalPremiumMonthly.value, 420);
      expect(spine.situation.totalDebt.value, 0);
      expect(digest.missingDomains, isNot(contains('situation')));
    });

    test('reuses BudgetLivingEngine snapshot as the budget source', () {
      final profile = buildProfile();
      final expectedBudget = BudgetLivingEngine.compute(profile);
      final spine = DataSpineService.fromProfile(profile, now: fixedNow);

      expect(
          spine.budget.monthlyFree, closeTo(expectedBudget.monthlyFree, 0.01));
      expect(spine.budget.stage, expectedBudget.stage);
      expect(spine.budget.confidenceScore, expectedBudget.confidenceScore);
    });

    test('derives AVS, LPP, and 3a pillar positions with fact state', () {
      final spine = DataSpineService.fromProfile(buildProfile(), now: fixedNow);

      expect(spine.pillars.avs.contributionYears.value, 18);
      expect(spine.pillars.avs.contributionYears.state, PillarFactState.known);
      expect(spine.pillars.avs.gaps.value, 2);
      expect(spine.pillars.lpp.totalBalance.value, 50000);
      expect(spine.pillars.lpp.totalBalance.state, PillarFactState.known);
      expect(spine.pillars.lpp.totalBalance.meta.source,
          ProfileDataSource.certificate);
      expect(spine.pillars.pillar3a.totalBalance.value, 12000);
      expect(spine.pillars.pillar3a.accountsCount.value, 1);
      expect(spine.pillars.pillar3a.annualContribution.value, 6000);
      expect(spine.pillars.pillar3a.annualContribution.meta.source,
          ProfileDataSource.userInput);
    });

    test('marks missing pillar facts as missing instead of estimating them',
        () {
      final spine = DataSpineService.fromProfile(
        buildProfile(prevoyance: const PrevoyanceProfile()),
        now: fixedNow,
      );

      expect(
          spine.pillars.avs.contributionYears.state, PillarFactState.missing);
      expect(spine.pillars.avs.estimatedMonthlyPension.state,
          PillarFactState.missing);
      expect(spine.pillars.lpp.totalBalance.state, PillarFactState.missing);
      expect(spine.pillars.lpp.insuredSalary.state, PillarFactState.missing);
      expect(
          spine.pillars.pillar3a.totalBalance.state, PillarFactState.missing);
    });

    test('uses field metadata from profile data sources and timestamps', () {
      final lppUpdatedAt = DateTime.utc(2026, 4, 20);
      final spine = DataSpineService.fromProfile(
        buildProfile(
          dataTimestamps: {
            'prevoyance.avoirLppTotal': lppUpdatedAt,
          },
        ),
        now: fixedNow,
      );

      final meta = spine.pillars.lpp.totalBalance.meta;
      expect(meta.source, ProfileDataSource.certificate);
      expect(meta.confidence, FieldConfidence.known);
      expect(meta.freshness, FieldFreshness.fresh);
      expect(meta.updatedAt, lppUpdatedAt);
    });

    test('exposes trust metadata for local-only spine facts', () {
      final spine = DataSpineService.fromProfile(buildProfile(), now: fixedNow);

      final sensitive = spine.pillars.lpp.totalBalance.meta;
      expect(sensitive.storageLocation, FieldStorageLocation.secureLocal);
      expect(sensitive.syncState, FieldSyncState.localOnly);
      expect(sensitive.aiSharingState, FieldAiSharingState.neverSent);
      expect(sensitive.deleteConsequence, FieldDeleteConsequence.clearsLocally);

      final nonSensitive = spine.situation.canton.meta;
      expect(nonSensitive.storageLocation, FieldStorageLocation.local);
      expect(nonSensitive.syncState, FieldSyncState.localOnly);
      expect(nonSensitive.aiSharingState, FieldAiSharingState.neverSent);
      expect(
        nonSensitive.deleteConsequence,
        FieldDeleteConsequence.clearsLocally,
      );
    });

    test('derives on-track trajectory when monthly capacity covers target', () {
      final spine = DataSpineService.fromProfile(
        buildProfile(
          goal: GoalA(
            type: GoalAType.custom,
            targetDate: DateTime.utc(2027, 5, 23),
            targetAmount: 1200,
            label: 'Coussin',
          ),
        ),
        now: fixedNow,
      );

      expect(spine.trajectory.status, TrajectoryStatus.onTrack);
      expect(spine.trajectory.monthlyRequired, closeTo(100, 0.01));
      expect(spine.trajectory.nextLeverId, 'maintain_plan');
    });

    test('derives blocked trajectory when current monthly free is negative',
        () {
      final spine = DataSpineService.fromProfile(
        buildProfile(
          loyer: 12000,
          goal: GoalA(
            type: GoalAType.custom,
            targetDate: DateTime.utc(2027, 5, 23),
            targetAmount: 1200,
            label: 'Coussin',
          ),
        ),
        now: fixedNow,
      );

      expect(spine.trajectory.status, TrajectoryStatus.blocked);
      expect(spine.trajectory.nextLeverId, 'stabilize_budget');
    });

    test('derives insufficientData trajectory without target amount', () {
      final spine = DataSpineService.fromProfile(buildProfile(), now: fixedNow);

      expect(spine.trajectory.status, TrajectoryStatus.insufficientData);
      expect(spine.trajectory.monthlyRequired, isNull);
    });
  });
}
