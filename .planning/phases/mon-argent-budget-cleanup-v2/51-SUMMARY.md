# Phase 51 — 3a Educational Insert Trust Copy

## Goal
Make the 3a educational insert frame fiscal figures as indicative reductions, not guaranteed monthly upside.

## Changes
- Replaced the visible `Économie d'impôts annuelle` label with `Réduction d’impôt indicative`.
- Replaced `de plus par mois` copy with `Impact indicatif: ... CHF par mois`.
- Added a widget regression test through `EducationalInsertService` for `q_has_3a`, covering the new labels and rejecting the old promise-like strings.

## Verification
- `flutter test test/services/educational_insert_service_test.dart` — passed.
- `flutter analyze lib/widgets/educational/tax_savings_insert_widget.dart test/services/educational_insert_service_test.dart` — no issues.
- `git diff --check` — passed.
- Targeted design lints for text style, color token, and radius — clean.
- `check_banned_terms` on the new labels — clean.
- `check_accent_patterns` on the new labels — clean.
- Claude Opus 4.7 review — APPROVE; noted only pre-existing hardcoded-French/i18n debt.

## Decision
Kept the calculation untouched. This phase only changes trust copy and test coverage because the numerical model is a broader actuarial/calculator concern.
