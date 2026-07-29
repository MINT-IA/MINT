# Phase 47 — Fix Mon Argent CTA Lint Placement

## Goal
Keep the branch CI-clean after expanding design-lint verification.

## Changes
- Moved the existing `prefer_mint_cta` inline ignores onto the same line as the raw `FilledButton` and `OutlinedButton` in `BudgetSummaryCard`.

## Verification
- `python3 tools/checks/prefer_mint_cta.py` — clean.
- `flutter analyze lib/widgets/mon_argent/budget_summary_card.dart` — no issues.

## Decision
No CTA component migration in this phase. The raw button widgets remain intentionally grandfathered until Phase 4 CTA unification; this phase only fixes the lint-ignore placement so CI reads the existing intent.
