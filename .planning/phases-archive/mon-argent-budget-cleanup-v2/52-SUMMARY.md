# Phase 52 — Independent 3a Recommendation Trust Copy

## Goal
Make the independent-worker 3a recommendation read as a conditional fiscal planning option, not a command to maximize or a guaranteed economy.

## Changes
- Replaced `verser le maximum annuel` with `Évaluer un versement ... jusqu'au plafond annuel`.
- Replaced `L'économie fiscale est significative` with `Impact fiscal indicatif selon ton taux marginal`.
- Added a focused `IndependantService` regression test covering the branch where `has3a` is false.

## Verification
- `flutter test test/services/segments_service_test.dart` — passed.
- `flutter analyze lib/services/segments_service.dart test/services/segments_service_test.dart` — no issues.
- `git diff --check` — passed.
- Targeted design lints for text style, color token, and radius — clean.
- `check_banned_terms` on the new recommendation — clean.
- `check_accent_patterns` on the new recommendation — clean.
- Claude Opus 4.7 review — APPROVE; noted only minor whitespace diff noise and no behavioral regression.

## Decision
Kept the service output shape unchanged. The phase only changes user-facing recommendation text and adds a regression test.
