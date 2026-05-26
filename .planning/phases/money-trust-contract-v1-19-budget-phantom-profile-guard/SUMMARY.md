# Phase 19 — Summary

## What Changed
- `BudgetInputs.fromCoachProfile` now includes profile expenses only when the
  corresponding field has a trusted source (`userInput`, `crossValidated`,
  `certificate`, `openBanking`) or is listed in `userProvidedFields`.
- Added a regression test in `budget_provider_test.dart` using
  `CoachProfile.fromWizardAnswers` without budget keys.
- Updated the explicit-budget profile fixture to declare trusted expense
  sources.

## Why It Matters
Mint must not invent a budget. A user can have a profile, income, and canton
without having entered rent or LAMal. Showing those internal defaults as a real
monthly budget damages trust and can drive wrong coach or report conclusions.

## Files
- `apps/mobile/lib/domain/budget/budget_inputs.dart`
- `apps/mobile/test/providers/budget/budget_provider_test.dart`

## Review Note
Claude Opus was run on the focused diff. The first pass flagged the exact
trust-chain risk: missing and estimated budget facts were being collapsed into
the same flags. Follow-up fixes added explicit missing flags for housing and
LAMal, kept `ProfileDataSource.estimated` distinct from user-provided values,
and made other fixed costs sum only sourced sub-posts.
