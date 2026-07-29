---
phase: mon-argent-budget-cleanup-v2
plan: 24
status: complete
created_at: 2026-05-27
branch: codex/mon-argent-budget-cleanup-v2
type: canton-fallback-trust-gate
---

# Plan 24 - Canton Fallback Trust Gate

## Goal

Stop the arbitrage summary from silently using Zurich tax assumptions when the
profile canton is missing or invalid.

## Changes

- Replaced `profile.canton.isNotEmpty ? profile.canton : 'ZH'` in
  `ArbitrageSummaryService.compute()` with `resolveCanton(profile.canton)`.
- When the canton is unresolved, the service now returns no arbitrage items and
  surfaces one locked item:
  - `id: canton`
  - title: `Canton fiscal`
  - route: `/profile/bilan`
- Debt-protection state is preserved even when the canton lock is active.
- Added a regression proving that a complete financial profile with missing
  canton no longer computes tax-sensitive arbitrages.

## Verification

- Red test first: missing canton previously produced 4 arbitrage items.
- Focused regression:
  `flutter test test/services/arbitrage_summary_service_test.dart --plain-name "missing canton suppresses arbitrages and asks for canton"`
- Summary/widget regression:
  `flutter test test/services/arbitrage_summary_service_test.dart test/widgets/dashboard/arbitrage_teaser_card_test.dart`
- Analyzer:
  `flutter analyze lib/services/arbitrage_summary_service.dart test/services/arbitrage_summary_service_test.dart`
- Diff hygiene:
  `git diff --check`
- Claude Opus 4.7 review:
  `NO_BLOCKING_FINDINGS`

## Notes

Claude noted the early return suppresses all arbitrages, not only fiscal ones.
That is intentional for this summary surface: the product posture is
lucidity-first, so the user sees a clear data lock instead of a mixed page with
some tax assumptions missing.
