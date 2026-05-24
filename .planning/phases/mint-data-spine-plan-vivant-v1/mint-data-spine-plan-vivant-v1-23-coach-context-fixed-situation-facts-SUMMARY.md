description: Plan 23 added housing cost, LAMal premium, and investments to the allowlisted coach context packet with targeted service coverage.

# Plan 23 — Summary

## Changed

- `CoachContextPacketService.allowedFactIds` now includes:
  - `situation.monthly_housing_cost`
  - `situation.lamal_premium_monthly`
  - `situation.investments`
- `_situationFacts` emits these values from `FinancialSituation` only when
  they are present.
- `coach_context_packet_service_test.dart` verifies the real `DataSpineService`
  fixture maps those values into the packet.

## Verification

- Red test confirmed the facts were missing before implementation.
- `flutter test test/services/coach_context_packet_service_test.dart --plain-name 'maps allowlisted known facts from DataSpineSnapshot'`
- `flutter test test/services/coach_context_packet_service_test.dart test/services/data_spine_service_test.dart`
- `flutter analyze lib/services/data_spine/coach_context_packet_service.dart test/services/coach_context_packet_service_test.dart`
