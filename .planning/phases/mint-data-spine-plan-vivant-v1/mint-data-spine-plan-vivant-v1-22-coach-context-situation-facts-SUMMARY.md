# Summary 22 — Coach context situation facts

## Shipped
- Added `situation.gross_annual_income`, `situation.liquid_savings`, and `situation.total_debt` to the strict coach fact allowlist.
- Emitted those facts from `FinancialSituation` when present.
- Extended the coach context packet test to lock the values.

## Validation
- `flutter analyze lib/services/data_spine/coach_context_packet_service.dart test/services/coach_context_packet_service_test.dart`
- `flutter test test/services/coach_context_packet_service_test.dart --plain-name 'maps allowlisted known facts from DataSpineSnapshot'`
- `flutter test test/services/coach_context_packet_service_test.dart test/services/data_spine_service_test.dart`
- 5 design lints, `git diff --check`

