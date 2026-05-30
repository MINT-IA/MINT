# Phase 18 - Arbitrage debt safety gate

## Goal

Do not present 3a/LPP/allocation arbitrages as the next best action when the
user has material consumer debt.

## Changes

- `ArbitrageSummaryService.compute` now checks
  `CoachProfile.hasMaterialConsumerDebtForPriority` before building arbitrage
  items.
- When the debt gate is active, the summary returns no optimization items and
  exposes a single `debt_protection` locked item routed to `/debt/ratio`.
- `ArbitrageBilanScreen` now passes localized strings into the summary service,
  so the protection item reuses existing Safe Mode copy.
- `ArbitrageBilanScreen` renders `debt_protection` as a protection card with a
  shield, not under the missing-data "Debloque" section.
- Added a regression with consumer debt capital and monthly repayment proving
  `rachat_vs_marche` and `allocation_annuelle` are suppressed.
- Added a screen regression proving the protection state is not shown as a
  locked missing-data item.

## Verification

- TDD: the new service test failed before the gate because the summary still
  contained `rente_vs_capital`, `rachat_vs_marche` and `allocation_annuelle`.
- `flutter test test/services/arbitrage_summary_service_test.dart --plain-name "debt crisis suppresses optimization arbitrages"`
- `flutter test test/services/arbitrage_summary_service_test.dart`
- `flutter test test/screens/arbitrage_screens_smoke_test.dart --plain-name "shows debt protection as a protection card, not a locked item"`
- `flutter test test/screens/arbitrage_screens_smoke_test.dart test/services/arbitrage_summary_service_test.dart`
- `flutter analyze lib/services/arbitrage_summary_service.dart lib/screens/arbitrage/arbitrage_bilan_screen.dart test/services/arbitrage_summary_service_test.dart`
- `flutter analyze lib/screens/arbitrage/arbitrage_bilan_screen.dart test/screens/arbitrage_screens_smoke_test.dart lib/services/arbitrage_summary_service.dart test/services/arbitrage_summary_service_test.dart`
- `git diff --check`
- `check_accent_patterns` on the debt protection copy: clean
- `check_banned_terms` on the debt protection copy: clean
- `validate_arb_parity`: OK, 6 locales, 6813 keys each
- Claude Opus 4.7 review:
  - first pass found overblocking, ASCII fallback accents and a test predicate
    mismatch;
  - final pass: `NO_BLOCKING_FINDINGS`.
- Claude Opus 4.7 UI review for the protection card: `NO_BLOCKING_FINDINGS`.

## Notes

- The gate deliberately uses `hasMaterialConsumerDebtForPriority`, not the
  broader `isInDebtCrisis`, because the latter can include missing emergency
  liquidity and would over-suppress users who only need a data/fund warning.
