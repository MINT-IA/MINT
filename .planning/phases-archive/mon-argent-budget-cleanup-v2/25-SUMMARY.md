---
phase: mon-argent-budget-cleanup-v2
plan: 25
status: complete
created_at: 2026-05-27
branch: codex/mon-argent-budget-cleanup-v2
type: dashboard-teaser-canton-gate
---

# Plan 25 - Dashboard Teaser Canton Gate

## Goal

Stop dashboard arbitrage teasers from silently computing with Zurich fallback
when the user's canton is unknown.

## Changes

- Added `resolveCanton(profile.canton)` to `ArbitrageTeaserSection`.
- If the canton is unresolved, the teaser section returns no teaser cards.
- Added a widget regression proving the teaser section stays hidden without a
  confirmed canton.

## Verification

- Red test first: a profile with empty canton still rendered `Pistes d'arbitrage`.
- Widget regression:
  `flutter test test/widgets/dashboard/arbitrage_teaser_card_test.dart`
- Analyzer:
  `flutter analyze lib/widgets/dashboard/arbitrage_teaser_card.dart test/widgets/dashboard/arbitrage_teaser_card_test.dart`
- Diff hygiene:
  `git diff --check`
- Claude Opus 4.7 review:
  `NO_BLOCKING_FINDINGS`

## Notes

This mirrors Plan 24 for the summary surface. The product rule is: no
tax-sensitive arbitrage teaser without a confirmed canton.
