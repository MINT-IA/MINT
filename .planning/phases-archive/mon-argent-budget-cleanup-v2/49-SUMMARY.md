# Phase 49 — Interactive Simulation Fiscal Wording

## Goal
Align the visible 3a and LPP interactive simulators with the trust-copy convention used elsewhere: estimated tax reduction, not “tax savings” framing.

## Changes
- Updated `Interactive3aSimulation` annual and cumulative tax labels from `Économie(s) fiscale(s)` wording to `Réduction d’impôt estimée`.
- Updated `InteractiveLppBuybackSimulation` tax label to `Réduction d’impôt estimée`.
- Swapped the fiscal metric icons from savings/star to calculation icons for clearer semantics.
- Added widget regression tests for both interactive simulators.

## Verification
- `flutter test test/widgets/interactive_simulations_test.dart` — passed.
- `flutter analyze lib/widgets/interactive_simulations.dart test/widgets/interactive_simulations_test.dart` — no issues.
- `git diff --check` — passed.
- `check_banned_terms` on the new phrases — clean.
- `check_accent_patterns` on the new phrases — clean.
- Claude Opus 4.7 review — APPROVE after confirming `S` is the generated localization class in this repo.

## Decision
Internal variables still use `taxSavings` names because this phase is limited to user-facing trust copy. Renaming internal model fields would be a broader migration and risks touching unrelated financial logic.
