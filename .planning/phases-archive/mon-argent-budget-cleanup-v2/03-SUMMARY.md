---
phase: mon-argent-budget-cleanup-v2
plan: 03
status: complete
completed_at: 2026-05-26
branch: codex/mon-argent-budget-cleanup-v2
---

# Summary — Patrimoine Debt Visibility

## Outcome

The patrimoine card now shows debts as a visible negative row when they are
part of the net worth calculation. A debt-only situation is no longer hidden
behind the empty-state prompt.

## Files

- `apps/mobile/lib/widgets/mon_argent/patrimoine_summary_card.dart`
- `apps/mobile/test/widgets/mon_argent_patrimoine_summary_card_test.dart`

## Verification

- `flutter test test/widgets/mon_argent_patrimoine_summary_card_test.dart`:
  3 passed.
- Focused Mon Argent/Data Spine/Budget suite: 67 passed.
- Targeted analyze: no issues.

## Next

Continue toward one visible value per financial fact: every amount used in a
net total should be legible on the same card or reachable through an explicit
drill-down.
