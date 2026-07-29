---
phase: mon-argent-budget-cleanup-v2
plan: 19
status: complete
created_at: 2026-05-27
branch: codex/mon-argent-budget-cleanup-v2
type: implementation-summary
---

# Plan 19 - Explicit Arbitrage Protection Contract

## Goal

Remove the fragile convention where `debt_protection` was transported as a
locked missing-data arbitrage and then filtered by id in the UI.

## Changes

- Added `ArbitrageProtection` and `ArbitrageSummary.protectionItems`.
- `ArbitrageSummaryService.compute` now emits debt safe-mode protection through
  `protectionItems`, while `lockedItems` remains dedicated to missing-data
  unlocks.
- `ArbitrageBilanScreen` consumes `summary.protectionItems` directly and no
  longer partitions `lockedItems` by `debt_protection`.
- Simplified the protection card semantics label to the localized title instead
  of a hardcoded French prefix.
- Updated the debt regression so `debt_protection` must be present in
  `protectionItems` and absent from `lockedItems`.

## Verification

- TDD red: the debt regression failed before `protectionItems` existed.
- `flutter test test/screens/arbitrage_screens_smoke_test.dart test/services/arbitrage_summary_service_test.dart`
- `flutter analyze lib/services/arbitrage_summary_service.dart lib/screens/arbitrage/arbitrage_bilan_screen.dart test/services/arbitrage_summary_service_test.dart test/screens/arbitrage_screens_smoke_test.dart`
- `git diff --check`
- `check_accent_patterns`: clean
- `check_banned_terms`: clean
- `validate_arb_parity`: OK, 6 locales, 6813 keys each
- Grep verification:
  - `ArbitrageSummary(` only constructed by `ArbitrageSummaryService.compute`
  - `/debt/ratio` registered in app routes and route metadata
  - `reportSafeModePriority` and `reportSafeModeActions` present in generated
    localizations and ARB files
- Claude Opus 4.7 review:
  - first pass: no blockers, recommended removing hardcoded French a11y prefix;
  - final pass after fix: `NO_BLOCKING_FINDINGS`.

## Notes

This is a small architecture cleanup, but important for trust: missing data,
computed opportunities and protective states are now three distinct channels.
