# Summary 45 — First-job 3a impact wiring

## Outcome

The first-job salary analyzer now carries the structured 3a tax-impact estimate
through its result object while preserving the legacy numeric field.

## Changes

- Added `impactFiscal3a` to `FirstJobResult`.
- Replaced the internal `estimate3aTaxSaving` call with `estimate3aTaxImpact`.
- Extended first-job tests to assert ceiling and estimated saving are distinct.

## Verification

- Red test first: missing `impactFiscal3a` failed.
- `flutter test test/services/first_job_service_test.dart`
- `flutter test test/services/tax_calculator_extended_test.dart test/services/first_job_service_test.dart`
- `flutter analyze lib/services/first_job_service.dart test/services/first_job_service_test.dart`
