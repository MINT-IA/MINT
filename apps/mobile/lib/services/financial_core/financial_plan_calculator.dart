import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/financial_plan_ledger_inputs.dart';

class FinancialPlanCalculation {
  final double monthlyTarget;
  final double projectedOutcome;
  final double? projectedLow;
  final double? projectedHigh;
  final List<PlanMilestone> milestones;
  final List<String> sources;
  final FinancialPlanProjectionAssumptions? projectionAssumptions;

  const FinancialPlanCalculation({
    required this.monthlyTarget,
    required this.projectedOutcome,
    required this.projectedLow,
    required this.projectedHigh,
    required this.milestones,
    required this.sources,
    required this.projectionAssumptions,
  });
}

/// Pure financial-plan calculations over an immutable ledger snapshot.
class FinancialPlanCalculator {
  FinancialPlanCalculator._();

  static FinancialPlanCalculation calculate({
    required String goalCategory,
    required double goalAmount,
    required DateTime targetDate,
    required DateTime now,
    required FinancialPlanLedgerInputs inputs,
    required double? prospectiveLppReturn,
  }) {
    final months = monthsRemaining(targetDate: targetDate, now: now);
    final milestones = FinancialPlan.generateMilestones(
      goalAmount,
      targetDate,
      now: now,
    );

    if (!_isRetirement(goalCategory)) {
      final monthlyTarget = goalAmount / months;
      return FinancialPlanCalculation(
        monthlyTarget: monthlyTarget,
        projectedOutcome: monthlyTarget * months,
        projectedLow: null,
        projectedHigh: null,
        milestones: milestones,
        sources: const [],
        projectionAssumptions: null,
      );
    }

    final retirementAge = inputs.ageAt(targetDate);
    if (retirementAge < 58 || retirementAge > 70) {
      throw ArgumentError.value(
        retirementAge,
        'targetDate',
        'retirement target age must be between 58 and 70',
      );
    }

    if (!inputs.hasPensionFund) {
      final monthlyTarget = goalAmount / months;
      return FinancialPlanCalculation(
        monthlyTarget: monthlyTarget,
        projectedOutcome: monthlyTarget * months,
        projectedLow: null,
        projectedHigh: null,
        milestones: milestones,
        sources: const [],
        projectionAssumptions: FinancialPlanProjectionAssumptions(
          caisseReturnBase: null,
          caisseReturnLow: null,
          caisseReturnHigh: null,
          supplementalMonthlySavingsReturn: 0,
          salaryBasis: const FinancialPlanSalaryBasis(
            kind: 'notApplicable',
          ),
          bonificationBasis: const FinancialPlanBonificationBasis(
            kind: 'notApplicable',
          ),
          projectionAsOf: now,
        ),
      );
    }
    if (inputs.confidenceLevel < ConfidenceScorer.minConfidenceForProjection) {
      throw ArgumentError.value(
        inputs.confidenceLevel,
        'confidenceLevel',
        'minimum projection confidence not reached',
      );
    }
    if (prospectiveLppReturn == null ||
        !prospectiveLppReturn.isFinite ||
        prospectiveLppReturn < 0 ||
        prospectiveLppReturn > 0.10) {
      throw ArgumentError.value(
        prospectiveLppReturn,
        'prospectiveLppReturn',
        'explicit future LPP return assumption between zero and 10% required',
      );
    }
    if (inputs.currentLppCapital == null) {
      throw ArgumentError('current combined LPP capital required');
    }
    final baseCapital = _projectRetirementCapital(
      inputs: inputs,
      retirementAge: retirementAge,
      caisseReturn: prospectiveLppReturn,
    );
    final gap = (goalAmount - baseCapital).clamp(0, double.infinity);
    final monthlyTarget = gap / months;
    final plannedContributions = monthlyTarget * months;

    final lowReturn = (prospectiveLppReturn - 0.01).clamp(0.0, 0.10).toDouble();
    final highReturn =
        (prospectiveLppReturn + 0.01).clamp(0.0, 0.10).toDouble();
    final lowCapital = _projectRetirementCapital(
      inputs: inputs,
      retirementAge: retirementAge,
      caisseReturn: lowReturn,
    );
    final highCapital = _projectRetirementCapital(
      inputs: inputs,
      retirementAge: retirementAge,
      caisseReturn: highReturn,
    );
    final projectedLow = lowCapital + plannedContributions;
    final projectedHigh = highCapital + plannedContributions;

    return FinancialPlanCalculation(
      monthlyTarget: monthlyTarget,
      projectedOutcome: baseCapital + plannedContributions,
      projectedLow: projectedLow,
      projectedHigh: projectedHigh,
      milestones: milestones,
      sources: const ['LPP art. 8', 'LPP art. 15–16'],
      projectionAssumptions: FinancialPlanProjectionAssumptions(
        caisseReturnBase: prospectiveLppReturn,
        caisseReturnLow: lowReturn,
        caisseReturnHigh: highReturn,
        supplementalMonthlySavingsReturn: 0,
        salaryBasis: FinancialPlanSalaryBasis(
          kind: 'monthlySalaryTimesTwelve',
          annualChf: inputs.grossAnnualSalary,
        ),
        bonificationBasis: const FinancialPlanBonificationBasis(
          kind: 'legalAgeSchedule',
        ),
        projectionAsOf: now,
      ),
    );
  }

  static double monthsRemaining({
    required DateTime targetDate,
    required DateTime now,
  }) {
    return ((targetDate.year - now.year) * 12 + (targetDate.month - now.month))
        .clamp(1, 9999)
        .toDouble();
  }

  static double _projectRetirementCapital({
    required FinancialPlanLedgerInputs inputs,
    required int retirementAge,
    required double caisseReturn,
  }) {
    return LppCalculator.projectCapitalToRetirement(
      currentCapital: inputs.currentLppCapital,
      currentAge: inputs.currentAge,
      retirementAge: retirementAge,
      grossAnnualSalary: inputs.grossAnnualSalary,
      caisseReturn: caisseReturn,
    ).projectedCapital;
  }

  static bool _isRetirement(String goalCategory) =>
      goalCategory == 'goal_retirement_plan' ||
      goalCategory == 'goal_pension_opt';
}
