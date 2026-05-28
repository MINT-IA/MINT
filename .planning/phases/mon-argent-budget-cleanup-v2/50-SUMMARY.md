# Phase 50 — Fiscal Move Comparison Difference Wording

## Goal
Make the canton move comparison read as an estimated difference, not a promised economy.

## Changes
- Replaced `Économie mensuelle`, `Économie annuelle`, and `Économie sur 10 ans` with `Écart ... estimé` labels in `MoveSavingsCard`.
- Added a widget regression test covering the visible labels and rejecting the old economy wording.

## Verification
- `flutter test test/widgets/fiscal/move_savings_card_test.dart` — passed.
- `flutter analyze lib/widgets/fiscal/move_savings_card.dart test/widgets/fiscal/move_savings_card_test.dart` — no issues.
- `git diff --check` — passed.
- `check_banned_terms` on the new labels — clean.
- `check_accent_patterns` on the new labels — clean.
- Targeted design lints for text style, color token, and radius — clean.
- Claude Opus 4.7 review — APPROVE; noted only the existing hardcoded-French debt and deferred internal parameter-name drift.

## Decision
Kept internal `economie*` parameter names unchanged. This widget likely sits on top of existing fiscal-service payloads; renaming the API would be a larger migration than the visible trust-copy cleanup.
