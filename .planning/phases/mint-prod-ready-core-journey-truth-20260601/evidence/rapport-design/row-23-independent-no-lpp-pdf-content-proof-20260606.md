---
description: Row 23 proof that the independent/no-LPP report guidance reaches the generated PDF content.
status: verified-local
date: 2026-06-06
linked_bug: CJT-063
---

# Row 23 - Independent/no-LPP PDF Content Proof

## Scope

This is a focused Row 23 / `CJT-063` proof for the
`independent_no_lpp_income_reality` persona.

It proves that the localized independent/no-LPP guidance action is not only
visible in `/rapport`, but also reaches the generated `mint_report_v2.pdf`
content extracted with `pdftotext`.

It does not close `CJT-063` and does not raise Row 23 beyond `PARTIAL`.

## Problem

After the `/rapport` independent/no-LPP guidance fix, one remaining gap in the
persona scorecard was:

- no PDF export content proof for the same persona.

Without this proof, the app could show neutral guidance on screen while the PDF
artifact drifted back to generic 3a account-opening or provider/product copy.

## Change

Added a PDF content regression in
`apps/mobile/test/services/pdf_service_test.dart`:

- builds a `FinancialReport` from independent/no-LPP answers for Nadia;
- passes generated French localization with `SFr()` so the test covers
  user-visible ARB output, not dead fallback strings;
- generates concrete `%PDF-` bytes through the mocked `PrintingPlatform`;
- extracts the rendered PDF text with `pdftotext`;
- collapses extraction whitespace so line wrapping does not create false
  failures;
- asserts that the PDF contains:
  - `Clarifier mon statut indépendant`;
  - `statut AVS indépendant`;
  - `absence d’affiliation LPP`;
  - `revenu imposable`;
  - `couvertures risque`;
- asserts that the PDF does not contain account-opening or `fintech` product
  framing for this persona.

The GitHub Actions services shard now installs `poppler-utils` so this PDF text
extraction proof runs in CI instead of silently skipping.

## Verification

Local commands:

```bash
cd apps/mobile
flutter test test/services/pdf_service_test.dart --plain-name "independent no-LPP report keeps verification guidance in PDF"
flutter test test/services/pdf_service_test.dart test/services/financial_report_service_test.dart
flutter analyze
```

Results:

- focused PDF persona test: pass;
- impact suite: `110/110` pass;
- `flutter analyze`: no issues.

Repo-level checks:

```bash
git diff --check
python3 tools/checks/mint_quality_os_check.py
python3 tools/checks/cjt_context_guard.py
python3 tools/checks/maestro_locator_audit.py
./tools/mint-routes check
```

Results:

- `git diff --check`: OK;
- `mint_quality_os_check`: OK;
- `cjt_context_guard`: OK;
- `maestro_locator_audit`: OK;
- `mint-routes check`: OK.

Review:

- Claude CLI first review found that a helper-level `markTestSkipped` did not
  short-circuit the test if `pdftotext` was missing. Fixed.
- Claude CLI second review found that the first version tested fallback strings
  rather than generated localization and would skip the strongest proof in CI.
  Fixed with `SFr()` and CI `poppler-utils`.
- Claude CLI final review: `No blockers`.
- Accessibility agent separately confirmed the next Row 23 lot should be
  `/rapport` + `/budget` focus traversal / VoiceOver proof.

## Remaining CJT-063 Work

Still required before closing `CJT-063`:

- VoiceOver/focus traversal proof for `/rapport` and `/budget`;
- broader PDF visual/page QA across report variants;
- source/provenance/freshness surfaced beside key money facts;
- Coach natural-language quality review for the same persona;
- updated persona-flow score above the current capped `6.3/10`.
