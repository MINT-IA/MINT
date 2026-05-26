import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/data_spine_snapshot.dart';
import 'package:mint_mobile/services/mon_argent/patrimoine_aggregator.dart';

void main() {
  group('PatrimoineAggregator', () {
    test('includes profile investments in patrimoine net worth', () {
      final summary = PatrimoineAggregator.compute(
        CoachProfile(
          birthYear: 1988,
          canton: 'VD',
          salaireBrutMensuel: 9000,
          prevoyance: const PrevoyanceProfile(
            avoirLppTotal: 120000,
            totalEpargne3a: 32000,
          ),
          patrimoine: const PatrimoineProfile(
            epargneLiquide: 30000,
            investissements: 12000,
          ),
          dettes: const DetteProfile(autresDettes: 10000),
          goalA: GoalA(
            type: GoalAType.achatImmo,
            targetDate: DateTime.utc(2035),
            label: 'Achat',
          ),
        ),
      );

      expect(summary.investissements?.value, 12000);
      expect(summary.totalActifs, 194000);
      expect(summary.net, 184000);
      expect(summary.completionRatio, 1);
    });

    test('includes data spine investments in patrimoine net worth', () {
      final summary = PatrimoineAggregator.computeFromDataSpine(
        _dataSpineWithInvestments(),
      );

      expect(summary.investissements?.value, 12000);
      expect(summary.totalActifs, 194000);
      expect(summary.net, 184000);
      expect(summary.lastUpdateSource, 'estimated');
    });
  });
}

DataSpineSnapshot _dataSpineWithInvestments() {
  final now = DateTime(2026, 5, 26);
  final userMeta = SpineFieldMeta(
    source: ProfileDataSource.userInput,
    confidence: FieldConfidence.known,
    freshness: FieldFreshness.fresh,
    updatedAt: DateTime(2026, 5, 25),
  );
  final estimatedMeta = SpineFieldMeta(
    source: ProfileDataSource.estimated,
    confidence: FieldConfidence.estimated,
    freshness: FieldFreshness.fresh,
    updatedAt: now,
  );

  return DataSpineSnapshot(
    situation: FinancialSituation(
      firstName: SpineValue(value: 'Julien', meta: userMeta),
      birthYear: SpineValue(value: 1988, meta: userMeta),
      canton: SpineValue(value: 'VD', meta: userMeta),
      commune: SpineValue(value: 'Lausanne', meta: userMeta),
      grossAnnualIncome: SpineValue(value: 108000, meta: userMeta),
      employmentStatus: SpineValue(value: 'salarie', meta: userMeta),
      monthlyHousingCost: SpineValue(value: 2400, meta: userMeta),
      lamalPremiumMonthly: SpineValue(value: 390, meta: userMeta),
      liquidSavings: SpineValue(value: 30000, meta: userMeta),
      investments: SpineValue(value: 12000, meta: estimatedMeta),
      totalDebt: SpineValue(value: 10000, meta: userMeta),
      housingStatus: SpineValue(value: 'locataire', meta: userMeta),
      activeGoalType: SpineValue(value: GoalAType.achatImmo, meta: userMeta),
    ),
    budget: const BudgetSnapshot(
      present: PresentBudget(
        monthlyNet: 8000,
        monthlyCharges: 5200,
        monthlySavings: 700,
        monthlyFree: 2100,
      ),
      capImpacts: [],
      stage: BudgetStage.presentOnly,
      confidenceScore: 64,
    ),
    pillars: PillarPosition(
      avs: const AvsPosition(
        contributionYears: PillarFact.missing(),
        gaps: PillarFact.missing(),
        estimatedMonthlyPension: PillarFact.missing(),
        ramd: PillarFact.missing(),
      ),
      lpp: LppPosition(
        totalBalance: PillarFact(
          value: 120000,
          state: PillarFactState.known,
          meta: userMeta,
        ),
        mandatoryBalance: const PillarFact.missing(),
        supplementaryBalance: const PillarFact.missing(),
        insuredSalary: const PillarFact.missing(),
        buybackMax: const PillarFact.missing(),
      ),
      pillar3a: Pillar3aPosition(
        totalBalance: PillarFact(
          value: 32000,
          state: PillarFactState.estimated,
          meta: userMeta,
        ),
        accountsCount: const PillarFact.missing(),
        annualContribution: const PillarFact.missing(),
        canContribute: true,
      ),
    ),
    trajectory: const TrajectorySummary(
      status: TrajectoryStatus.onTrack,
      currentMonthlyFree: 2100,
      currentMonthlyCapacity: 2800,
      targetAmount: 120000,
      monthsToTarget: 42,
      monthlyRequired: 2500,
      monthlyGap: -300,
      nextLeverId: 'increase_savings',
    ),
    computedAt: now,
  );
}
