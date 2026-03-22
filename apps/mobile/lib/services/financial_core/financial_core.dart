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
export 'avs_calculator.dart';
export 'cross_pillar_calculator.dart';
export 'bayesian_enricher.dart';
export 'coach_reasoner.dart';
export 'confidence_scorer.dart';
export 'fri_calculator.dart';
export 'housing_cost_calculator.dart';
export 'lpp_calculator.dart';
export 'monte_carlo_models.dart';
export 'monte_carlo_service.dart';
export 'tax_calculator.dart';
export 'tornado_sensitivity_service.dart';
export 'withdrawal_sequencing_service.dart';
