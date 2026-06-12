/// Shared financial core — pure calculators used by all projection services.
///
/// This library extracts common financial calculations into static,
/// pure functions that both RetirementProjectionService and ForecasterService
/// can share, ensuring consistent results across the app.
///
/// Reference: ADR-20260223-unified-financial-engine.md
library;

export 'arbitrage_engine.dart';
export 'arbitrage_models.dart';
export 'archetype_predicates.dart';
export 'avs_calculator.dart';
export 'cross_pillar_calculator.dart';
export 'bayesian_enricher.dart';
// coach_reasoner.dart removed in mint-grounded-coach-m1 Plan 07 (WS-C
// activate-or-delete): CoachReasonerService had zero production callers
// (audit 01 HOLE-5) — a façade per NEVER #6. Git history preserves it for a
// future M3 revival; deleted here with its tests.
export 'confidence_scorer.dart';
export 'couple_optimizer.dart';
export 'fri_calculator.dart';
export 'housing_cost_calculator.dart';
export 'lpp_calculator.dart';
export 'monte_carlo_models.dart';
export 'monte_carlo_service.dart';
export 'pillar3a_room_calculator.dart';
export 'replacement_rate.dart';
export 'tax_calculator.dart';
export 'tornado_sensitivity_service.dart';
export 'withdrawal_sequencing_service.dart';
