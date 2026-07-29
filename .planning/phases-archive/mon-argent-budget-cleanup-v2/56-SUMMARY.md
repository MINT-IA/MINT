# Phase 56 — Remaining Visible Fiscal Trust Copy

## Goal
Remove the remaining visible/assistive `économie fiscale` and winner-like copy from canton comparison and couple LPP ordering surfaces.

## Changes
- Replaced couple LPP ordering reason text with an indicative tax-reduction comparison tied to estimated marginal tax rate.
- Reframed `TopCantonWidget` from a winner/ranking promise (`Ton top`, `n°1`, `Tu économises`, `moins cher`) to scenario comparison language.
- Updated the accessibility label to `Comparaison indicative de cantons pour déménagement`.
- Added regression tests that assert the new wording and reject the old promise-like terms.

## Verification
- `flutter test test/services/financial_core/couple_optimizer_test.dart test/widgets/coach/top_cantons_widget_test.dart` — passed.
- `flutter analyze lib/services/financial_core/couple_optimizer.dart lib/widgets/coach/top_cantons_widget.dart test/services/financial_core/couple_optimizer_test.dart test/widgets/coach/top_cantons_widget_test.dart` — no issues.
- `git diff --check` — passed.
- Targeted design lints for text style, color token, and radius — clean.
- `check_banned_terms` on the new strings — clean.
- `check_accent_patterns` on the new strings — clean.
- Claude Opus 4.7 review — APPROVE.

## Decision
Kept internal model names such as `annualTaxSaving` unchanged. The phase targets user-facing and assistive text only; internal naming can be handled in a later mechanical cleanup if needed.
