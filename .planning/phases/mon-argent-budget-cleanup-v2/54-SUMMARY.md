# Phase 54 — Financial PDF LPP Tax Reduction Labels

## Goal
Remove promise-like `Économie fiscale` labels from the LPP buyback section of the financial PDF.

## Changes
- Replaced `Économie fiscale totale estimée` with `Réduction d’impôt totale estimée`.
- Replaced the yearly plan column `Économie fiscale` with `Réduction d’impôt estimée`.
- Extracted both labels into `@visibleForTesting` constants and added regression assertions.

## Verification
- `flutter test test/services/pdf_service_test.dart` — passed.
- `flutter analyze lib/services/pdf_service.dart test/services/pdf_service_test.dart` — no issues.
- `git diff --check` — passed.
- `check_banned_terms` on the new labels — clean.
- `check_accent_patterns` on the new labels — clean.
- Claude Opus 4.7 review — APPROVE.
- `rg` confirms production `pdf_service.dart` no longer contains `Économie fiscale` / `économie fiscale`.

## Note
The full PDF file still has legacy `fontSize` design-lint debt. This phase does not touch it because the staged trust-copy diff is narrow and the pre-commit gate scopes linting to staged changes.
