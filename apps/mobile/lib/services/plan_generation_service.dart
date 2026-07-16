import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/services/financial_core/financial_plan_calculator.dart';
import 'package:mint_mobile/services/financial_plan_ledger_inputs.dart';

const mandatoryMintPlanDisclaimer =
    'Les résultats présentés sont des estimations à titre indicatif, ' // lint-ignore: persisted compatibility; ARB owns UI copy.
    'basées sur les données fournies et la législation en vigueur. ' // lint-ignore: persisted compatibility; ARB owns UI copy.
    'Ils ne constituent pas un conseil financier personnalisé. ' // lint-ignore: persisted compatibility; ARB owns UI copy.
    'Consultez un·e spécialiste pour votre situation spécifique.'; // lint-ignore: persisted compatibility; ARB owns UI copy.

/// Creates a plan from a user-owned goal and one immutable ledger snapshot.
///
/// Financial calculations live in [FinancialPlanCalculator]. The returned plan
/// is not persisted here; [FinancialPlanProvider] owns that save queue.
class PlanGenerationService {
  PlanGenerationService._();

  static Future<FinancialPlan> generate({
    required String goalDescription,
    required String goalCategory,
    required DateTime targetDate,
    required CoachProfile profile,
    double? goalAmount,
    double? prospectiveLppReturn,
    DateTime? now,
  }) async {
    final generatedAt = now ?? DateTime.now();
    if (!targetDate.isAfter(generatedAt)) {
      throw ArgumentError.value(
        targetDate,
        'targetDate',
        'future user-owned target date required',
      );
    }
    if (goalAmount == null || !goalAmount.isFinite || goalAmount <= 0) {
      throw ArgumentError.value(
        goalAmount,
        'goalAmount',
        'finite positive user-owned amount required',
      );
    }

    final inputs =
        FinancialPlanLedgerInputs.fromProfile(profile, now: generatedAt);
    final calculation = FinancialPlanCalculator.calculate(
      goalCategory: goalCategory,
      goalAmount: goalAmount,
      targetDate: targetDate,
      now: generatedAt,
      inputs: inputs,
      prospectiveLppReturn: prospectiveLppReturn,
    );
    final scenarioId =
        'scenario-${generatedAt.microsecondsSinceEpoch}-${goalCategory.hashCode.abs()}';
    return FinancialPlan(
      id: '${generatedAt.microsecondsSinceEpoch}_${goalCategory.hashCode.abs()}',
      goalDescription: goalDescription,
      goalCategory: goalCategory,
      monthlyTarget: calculation.monthlyTarget,
      milestones: calculation.milestones,
      projectedOutcome: calculation.projectedOutcome,
      projectedLow: calculation.projectedLow,
      projectedHigh: calculation.projectedHigh,
      targetDate: targetDate,
      generatedAt: generatedAt,
      profileHashAtGeneration: inputs.fingerprint,
      coachNarrative: _defaultNarrative(
        goalCategory,
      ),
      confidenceLevel: inputs.confidenceLevel,
      sources: calculation.sources,
      disclaimer: mandatoryMintPlanDisclaimer,
      goalAmount: goalAmount,
      scenarioId: scenarioId,
      confirmedAt: generatedAt,
      inputAsOf: inputs.capturedAt,
      projectionAssumptions: calculation.projectionAssumptions,
    );
  }

  // Compatibility token only. Product surfaces derive localized explanatory
  // copy from the app-owned category and structured calculator assumptions.
  static String _defaultNarrative(String goalCategory) =>
      'mint-plan-narrative:v2:$goalCategory';
}
