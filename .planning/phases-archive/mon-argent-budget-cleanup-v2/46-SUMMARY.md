# Phase 46 — Align Financial PDF LPP Wording

## Goal
Remove the remaining user-facing PDF wording that framed LPP buyback impact as an `économie`, and replace it with a clearer estimated tax-reduction label.

## Changes
- Updated `apps/mobile/lib/services/pdf_service.dart` financial PDF copy from `économie` to `réduction d’impôt estimée` for the LPP buyback line.
- Extracted the LPP buyback PDF line into a small formatter used by the PDF template, exposed through a `@visibleForTesting` test hook.
- Added a guard test in `apps/mobile/test/services/pdf_service_test.dart` that checks the formatter output and rejects saving-language wording.
- Refreshed the LINT-02 text-style baseline after the `pdf_service.dart` line-number shift; this also removed stale baseline rows already clean on the branch.

## Verification
- `flutter test test/services/pdf_service_test.dart` — 16 passed.
- `flutter analyze lib/services/pdf_service.dart test/services/pdf_service_test.dart` — no issues.
- `python3 tools/checks/prefer_mint_text_style.py` — clean.
- `git diff --check` — passed.
- `check_banned_terms` on the new French phrase — clean.
- `check_accent_patterns` on the new French phrase — clean.

## Review
- Claude Opus 4.7 initially blocked a source-grep test and challenged `impact fiscal estimé` as directionally ambiguous in a PDF line.
- Resolution: keep the phase focused but replace the source-grep test with a formatter behavior test, and use `réduction d’impôt estimée` to preserve direction without promising a guaranteed saving.
- Final Claude Opus 4.7 review: APPROVE; previous blockers resolved, with only a non-blocking note that the test hook is a standard Flutter seam.

## Decision
No broader PDF refactor in this phase. The remaining PDF hardcoded labels are a separate localization/templating cleanup; this phase only closes the trust issue around over-promising fiscal savings.
