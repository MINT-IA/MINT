/// Shared financial core — pure calculators used by all projection services.
///
/// This library extracts common financial calculations into static,
/// pure functions that both RetirementProjectionService and ForecasterService
/// can share, ensuring consistent results across the app.
///
/// Reference: ADR-20260223-unified-financial-engine.md
library;

export 'avs_calculator.dart';
export 'confidence_scorer.dart';
export 'lpp_calculator.dart';
export 'tax_calculator.dart';
export 'tornado_sensitivity_service.dart';
