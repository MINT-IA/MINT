/// BudgetSnapshot — unified budget state for Aujourd'hui + Coach.
///
/// Spec: docs/BUDGET_LIVING_ENGINE_IMPLEMENTATION_SPEC.md
/// Created: S53 — BudgetLivingEngine V0
library;

import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/coach_profile.dart';

/// Progressive disclosure stage based on confidence + data availability.
enum BudgetStage {
  /// Only present budget available (low confidence or retirement not computable).
  presentOnly,

  /// Retirement budget emerging but confidence still moderate.
  emergingRetirement,

  /// Full gap visible — both budgets defensible.
  fullGapVisible,
}

/// Present-day monthly budget: income, charges, free.
class PresentBudget {
  final double monthlyIncome;
  final double monthlyCharges;
  final double monthlyFree;

  const PresentBudget({
    required this.monthlyIncome,
    required this.monthlyCharges,
    required this.monthlyFree,
  });
}

/// Estimated monthly retirement budget from all 3 pillars.
class RetirementBudget {
  final double avsMonthly;
  final double lppMonthly;
  final double pillar3aMonthly;
  final double otherMonthly;
  final double monthlyCharges;
  final double monthlyFree;

  const RetirementBudget({
    required this.avsMonthly,
    required this.lppMonthly,
    required this.pillar3aMonthly,
    required this.otherMonthly,
    required this.monthlyCharges,
    required this.monthlyFree,
  });

  /// Total monthly retirement income (all pillars).
  double get totalMonthlyIncome =>
      avsMonthly + lppMonthly + pillar3aMonthly + otherMonthly;
}

/// Gap between present and retirement free monthly amounts.
class BudgetGap {
  final double monthlyGap;
  final double ratioRetained;
  final bool isPositive;

  const BudgetGap({
    required this.monthlyGap,
    required this.ratioRetained,
    required this.isPositive,
  });
}

/// Short-term / long-term impact of the current cap lever.
class BudgetCapImpact {
  final String? now;
  final String? later;
  final String? sequence;

  const BudgetCapImpact({
    this.now,
    this.later,
    this.sequence,
  });
}

/// One step in a multi-year strategy sequence.
class BudgetCapSequenceStep {
  final String label;
  final String effect;

  const BudgetCapSequenceStep({
    required this.label,
    required this.effect,
  });
}

/// A multi-step strategy (e.g. staggered LPP buybacks).
class BudgetCapSequence {
  final String title;
  final List<BudgetCapSequenceStep> steps;
  final String? cumulativeBenefit;

  const BudgetCapSequence({
    required this.title,
    required this.steps,
    this.cumulativeBenefit,
  });
}

/// Unified budget snapshot — single object that feeds Aujourd'hui + Coach.
///
/// Created by [BudgetLivingEngine.compute()].
/// Spec: docs/BUDGET_LIVING_ENGINE_IMPLEMENTATION_SPEC.md
class BudgetSnapshot {
  final PresentBudget present;
  final RetirementBudget? retirement;
  final BudgetGap? gap;
  final CapDecision cap;
  final BudgetCapImpact? capImpact;
  final BudgetCapSequence? capSequence;
  final int confidenceScore;
  final BudgetStage stage;
  final GoalA? activeGoal;
  final List<CapSignal> supportingSignals;
  final DateTime computedAt;

  const BudgetSnapshot({
    required this.present,
    this.retirement,
    this.gap,
    required this.cap,
    this.capImpact,
    this.capSequence,
    required this.confidenceScore,
    required this.stage,
    this.activeGoal,
    required this.supportingSignals,
    required this.computedAt,
  });
}
