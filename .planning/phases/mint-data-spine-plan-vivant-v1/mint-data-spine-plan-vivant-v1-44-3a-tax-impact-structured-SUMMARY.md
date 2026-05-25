# Summary 44 — Structured 3a tax impact

## Outcome

The 3a tax calculation now returns a structured estimate instead of forcing
callers to infer what a single number means.

## Changes

- Added `Pillar3aTaxImpactEstimate`, confidence enum, and
  `RetirementTaxCalculator.estimate3aTaxImpact`.
- Kept `estimate3aTaxSaving` as a wrapper and added scanned marginal-rate
  support to `estimateTaxSaving`.

## Verification

- Red test first: missing method and enum failed.
- `flutter test test/services/tax_calculator_extended_test.dart`
- `flutter test test/services/financial_core/tax_calculator_test.dart test/services/first_job_service_test.dart test/services/cap_sequence_engine_test.dart`
- `flutter analyze lib/services/financial_core/tax_calculator.dart test/services/tax_calculator_extended_test.dart`
