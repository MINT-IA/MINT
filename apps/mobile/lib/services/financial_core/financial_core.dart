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
export 'couple_optimizer.dart';
export 'disability_insurance_calculator.dart';
export 'emergency_fund_heuristic.dart';
export 'fri_calculator.dart';
export 'gift_tax_confirmation.dart';
export 'housing_cost_calculator.dart';
export 'lamal_premium_normalizer.dart';
export 'lpp_contribution_calculator.dart';
export 'lpp_calculator.dart';
export 'monte_carlo_models.dart';
export 'monte_carlo_service.dart';
export 'replacement_rate_calculator.dart';
export 'succession_reserve_calculator.dart';
export 'tax_calculator.dart';
export 'tax_document_ratio_calculator.dart';
export 'sensitivity_models.dart';
export 'wealth_financial_facts.dart';
export 'withdrawal_sequencing_service.dart';
