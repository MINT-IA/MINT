# Phase 48 — Retirement Checklist Tax Wording

## Goal
Remove another visible “tax saving” framing from the retirement checklist while preserving a clear direction for the user.

## Changes
- Updated the LPP buyback checklist subtitle from `Économie d’impôt estimée` to `Réduction d’impôt estimée`.
- Added a widget regression test covering the visible LPP buyback checklist item and rejecting the previous `Économie d’impôt` wording.

## Verification
- `flutter test test/widgets/dashboard/retirement_checklist_card_test.dart` — passed.
- `flutter analyze lib/widgets/dashboard/retirement_checklist_card.dart test/widgets/dashboard/retirement_checklist_card_test.dart` — no issues.
- `git diff --check` — passed.
- `check_banned_terms` on the new phrase — clean.
- `check_accent_patterns` on the new phrase — clean.
- Claude Opus 4.7 review — APPROVE; noted only the existing hardcoded-French debt in this legacy widget.

## Decision
No broad retirement checklist refactor in this phase. The file still has legacy hardcoded French copy; this phase only removes a concrete fiscal-trust regression and locks it with a focused widget test.
