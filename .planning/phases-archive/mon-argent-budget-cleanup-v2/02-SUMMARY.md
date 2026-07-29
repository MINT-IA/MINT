---
phase: mon-argent-budget-cleanup-v2
plan: 02
status: complete
completed_at: 2026-05-26
branch: codex/mon-argent-budget-cleanup-v2
---

# Summary — Patrimoine Investments Convergence

## Outcome

`PatrimoineAggregator` now treats free investments as a first-class asset in
Mon Argent. Profile-derived and Data Spine-derived summaries both include
investments in total assets, net worth, freshness/source selection and
completion ratio. The patrimoine card renders the existing localized
`financialSummaryInvestissements` row instead of hiding that value.

## Files

- `apps/mobile/lib/services/mon_argent/patrimoine_aggregator.dart`
- `apps/mobile/lib/widgets/mon_argent/patrimoine_summary_card.dart`
- `apps/mobile/test/services/mon_argent_patrimoine_aggregator_test.dart`
- `apps/mobile/test/widgets/mon_argent_patrimoine_summary_card_test.dart`

## Verification

- `flutter test test/services/mon_argent_patrimoine_aggregator_test.dart test/widgets/mon_argent_patrimoine_summary_card_test.dart`:
  3 passed.
- Focused Mon Argent/Data Spine/Budget suite: 65 passed.
- Targeted analyze: no issues.

## Next

Continue Mon Argent convergence with the same rule: one canonical read model
per screen section, no duplicate visible totals, and tests that prove the same
user facts produce the same card values.
