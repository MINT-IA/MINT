import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/data_spine_snapshot.dart';
import 'package:mint_mobile/services/data_spine/data_spine_readiness_digest_service.dart';
import 'package:mint_mobile/services/data_spine/data_spine_service.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 5, 23, 12);

  CoachProfile buildProfile({
    PrevoyanceProfile prevoyance = const PrevoyanceProfile(
      anneesContribuees: 18,
      lacunesAVS: 0,
      renteAVSEstimeeMensuelle: 1800,
      ramd: 88200,
      avoirLppTotal: 50000,
      avoirLppObligatoire: 32000,
      avoirLppSurobligatoire: 18000,
      rachatMaximum: 25000,
      salaireAssure: 70000,
      nombre3a: 1,
      totalEpargne3a: 12000,
    ),
    GoalA? goal,
    double loyer = 2100,
    int birthYear = 1987,
    String canton = 'VD',
  }) {
    return CoachProfile(
      firstName: 'Julien',
      birthYear: birthYear,
      canton: canton,
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
            type: GoalAType.custom,
            targetDate: DateTime.utc(2027, 5, 23),
            targetAmount: 1200,
            label: 'Coussin',
          ),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 5, 1),
    );
  }

  DataSpineReadinessSection section(
    DataSpineReadinessDigest digest,
    String id,
  ) {
    return digest.sections.singleWhere((section) => section.id == id);
  }

  group('DataSpineReadinessDigestService', () {
    test(
        'marks the data spine ready when situation, pillars, and trajectory are usable',
        () {
      final spine = DataSpineService.fromProfile(buildProfile(), now: fixedNow);

      final digest = DataSpineReadinessDigestService.fromSpine(spine);

      expect(digest.overallStatus, DataSpineReadinessStatus.ready);
      expect(digest.nextActionId, 'maintain_plan');
      expect(digest.computedAt, fixedNow);
      expect(digest.missingDomains, isEmpty);
      expect(
          section(digest, 'situation').status, DataSpineReadinessStatus.ready);
      expect(section(digest, 'budget').status, DataSpineReadinessStatus.ready);
      expect(section(digest, 'pillars').status, DataSpineReadinessStatus.ready);
      expect(
          section(digest, 'trajectory').status, DataSpineReadinessStatus.ready);
    });

    test(
        'keeps a partial digest when useful current data exists but target and pillars are incomplete',
        () {
      final spine = DataSpineService.fromProfile(
        buildProfile(
          prevoyance: const PrevoyanceProfile(),
          goal: GoalA(
            type: GoalAType.custom,
            targetDate: DateTime.utc(2027, 5, 23),
            label: 'Coussin',
          ),
        ),
        now: fixedNow,
      );

      final digest = DataSpineReadinessDigestService.fromSpine(spine);

      expect(digest.overallStatus, DataSpineReadinessStatus.partial);
      expect(digest.nextActionId, 'define_target');
      expect(
          digest.missingDomains,
          containsAll(<String>[
            'pillar_avs',
            'pillar_lpp',
            'pillar_3a',
            'trajectory',
          ]));
      expect(
          section(digest, 'situation').status, DataSpineReadinessStatus.ready);
      expect(section(digest, 'budget').status, DataSpineReadinessStatus.ready);
      expect(
          section(digest, 'pillars').status, DataSpineReadinessStatus.partial);
      expect(section(digest, 'trajectory').status,
          DataSpineReadinessStatus.partial);
    });

    test(
        'prioritizes stabilizing the budget when monthly free cashflow is negative',
        () {
      final spine = DataSpineService.fromProfile(
        buildProfile(loyer: 12000),
        now: fixedNow,
      );

      final digest = DataSpineReadinessDigestService.fromSpine(spine);

      expect(digest.overallStatus, DataSpineReadinessStatus.blocked);
      expect(digest.nextActionId, 'stabilize_budget');
      expect(digest.missingDomains, contains('budget'));
      expect(
          section(digest, 'budget').status, DataSpineReadinessStatus.blocked);
      expect(section(digest, 'trajectory').status,
          DataSpineReadinessStatus.blocked);
    });

    test('reports missing situation fields before claiming a maintainable plan',
        () {
      final spine = DataSpineService.fromProfile(
        buildProfile(birthYear: 0, canton: ''),
        now: fixedNow,
      );

      final digest = DataSpineReadinessDigestService.fromSpine(spine);

      expect(digest.overallStatus, DataSpineReadinessStatus.partial);
      expect(digest.missingDomains, contains('situation'));
      expect(digest.nextActionId, 'complete_situation');
      expect(section(digest, 'situation').status,
          DataSpineReadinessStatus.partial);
    });

    test('uses BudgetSnapshot as the canonical source for deficit readiness',
        () {
      final base = DataSpineService.fromProfile(buildProfile(), now: fixedNow);
      final spine = DataSpineSnapshot(
        situation: base.situation,
        budget: const BudgetSnapshot(
          present: PresentBudget(
            monthlyNet: 7000,
            monthlyCharges: 7100,
            monthlySavings: 0,
            monthlyFree: -100,
          ),
          capImpacts: [],
          stage: BudgetStage.presentOnly,
          confidenceScore: 80,
        ),
        pillars: base.pillars,
        trajectory: const TrajectorySummary(
          status: TrajectoryStatus.onTrack,
          currentMonthlyFree: 3500,
          currentMonthlyCapacity: 4000,
          targetAmount: 1200,
          monthsToTarget: 12,
          monthlyRequired: 100,
          monthlyGap: -3900,
          nextLeverId: 'synthetic_action_from_spine',
        ),
        computedAt: fixedNow,
      );

      final digest = DataSpineReadinessDigestService.fromSpine(spine);

      expect(digest.overallStatus, DataSpineReadinessStatus.blocked);
      expect(digest.nextActionId, 'stabilize_budget');
      expect(digest.missingDomains, contains('budget'));
      expect(
          section(digest, 'budget').status, DataSpineReadinessStatus.blocked);
      expect(
          section(digest, 'trajectory').status, DataSpineReadinessStatus.ready);
    });

    test(
        'returns stable section and missing-domain order for the same snapshot',
        () {
      final spine = DataSpineService.fromProfile(
        buildProfile(prevoyance: const PrevoyanceProfile()),
        now: fixedNow,
      );

      final first = DataSpineReadinessDigestService.fromSpine(spine);
      final second = DataSpineReadinessDigestService.fromSpine(spine);

      expect(first.sections.map((section) => section.id), <String>[
        'situation',
        'budget',
        'pillars',
        'trajectory',
      ]);
      expect(second.sections.map((section) => section.id),
          first.sections.map((section) => section.id));
      expect(second.missingDomains, first.missingDomains);
      expect(second.nextActionId, first.nextActionId);
    });

    test(
        'reads trajectory action from a synthetic spine without recomputing it',
        () {
      final spine = DataSpineSnapshot(
        situation: const FinancialSituation(
          firstName: SpineValue(
            value: 'Julien',
            meta: SpineFieldMeta.missing(),
          ),
          birthYear: SpineValue(
            value: 1987,
            meta: SpineFieldMeta.missing(),
          ),
          canton: SpineValue(
            value: 'VD',
            meta: SpineFieldMeta.missing(),
          ),
          commune: SpineValue(
            value: 'Lausanne',
            meta: SpineFieldMeta.missing(),
          ),
          grossAnnualIncome: SpineValue(
            value: 104000,
            meta: SpineFieldMeta.missing(),
          ),
          employmentStatus: SpineValue(
            value: 'salarie',
            meta: SpineFieldMeta.missing(),
          ),
          monthlyHousingCost: SpineValue(
            value: 2100,
            meta: SpineFieldMeta.missing(),
          ),
          lamalPremiumMonthly: SpineValue(
            value: 430,
            meta: SpineFieldMeta.missing(),
          ),
          liquidSavings: SpineValue(
            value: 18000,
            meta: SpineFieldMeta.missing(),
          ),
          investments: SpineValue(
            value: 7000,
            meta: SpineFieldMeta.missing(),
          ),
          totalDebt: SpineValue(
            value: 3000,
            meta: SpineFieldMeta.missing(),
          ),
          housingStatus: SpineValue(
            value: 'locataire',
            meta: SpineFieldMeta.missing(),
          ),
          activeGoalType: SpineValue(
            value: GoalAType.custom,
            meta: SpineFieldMeta.missing(),
          ),
        ),
        budget: const BudgetSnapshot(
          present: PresentBudget(
            monthlyNet: 7000,
            monthlyCharges: 3000,
            monthlySavings: 500,
            monthlyFree: 3500,
          ),
          capImpacts: [],
          stage: BudgetStage.presentOnly,
          confidenceScore: 80,
        ),
        pillars: const PillarPosition(
          avs: AvsPosition(
            contributionYears: PillarFact(
              value: 18,
              state: PillarFactState.known,
              meta: SpineFieldMeta.missing(),
            ),
            gaps: PillarFact(
              value: 0,
              state: PillarFactState.known,
              meta: SpineFieldMeta.missing(),
            ),
            estimatedMonthlyPension: PillarFact(
              value: 1800,
              state: PillarFactState.known,
              meta: SpineFieldMeta.missing(),
            ),
            ramd: PillarFact.missing(),
          ),
          lpp: LppPosition(
            totalBalance: PillarFact(
              value: 50000,
              state: PillarFactState.known,
              meta: SpineFieldMeta.missing(),
            ),
            mandatoryBalance: PillarFact.missing(),
            supplementaryBalance: PillarFact.missing(),
            insuredSalary: PillarFact(
              value: 70000,
              state: PillarFactState.known,
              meta: SpineFieldMeta.missing(),
            ),
            buybackMax: PillarFact(
              value: 25000,
              state: PillarFactState.known,
              meta: SpineFieldMeta.missing(),
            ),
          ),
          pillar3a: Pillar3aPosition(
            totalBalance: PillarFact(
              value: 12000,
              state: PillarFactState.known,
              meta: SpineFieldMeta.missing(),
            ),
            accountsCount: PillarFact(
              value: 1,
              state: PillarFactState.known,
              meta: SpineFieldMeta.missing(),
            ),
            annualContribution: PillarFact.missing(),
            canContribute: true,
          ),
        ),
        trajectory: const TrajectorySummary(
          status: TrajectoryStatus.onTrack,
          currentMonthlyFree: 3500,
          currentMonthlyCapacity: 4000,
          targetAmount: 1200,
          monthsToTarget: 12,
          monthlyRequired: 100,
          monthlyGap: -3900,
          nextLeverId: 'synthetic_action_from_spine',
        ),
        computedAt: fixedNow,
      );

      final digest = DataSpineReadinessDigestService.fromSpine(spine);

      expect(digest.overallStatus, DataSpineReadinessStatus.ready);
      expect(digest.nextActionId, 'synthetic_action_from_spine');
    });
  });
}
