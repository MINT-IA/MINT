---
phase: 02-intelligence-documentaire
plan: 03
subsystem: ui
tags: [flutter, document-scan, confidence-thresholds, lpp-1e-warning, coherence-validation, source-text, i18n]

# Dependency graph
requires:
  - phase: 02-intelligence-documentaire
    plan: 01
    provides: Pre-extraction classification (422 for non-financial docs), audit log
  - phase: 02-intelligence-documentaire
    plan: 02
    provides: plan_type, plan_type_warning, coherence_warnings on VisionExtractionResponse
provides:
  - Per-field confidence thresholds in extraction_review_screen (DOC-03)
  - LPP 1e warning banner and coherence warning banners in Flutter UI
  - Source text display per field with "Source : " prefix
  - Pre-validation error display for 422 non-financial document rejection
  - Client-side file validation (10MB max, format check)
  - 10 new i18n keys in all 6 ARB files
affects: [02-intelligence-documentaire, 06-qa-profond]

# Tech tracking
tech-stack:
  added: []
  patterns: [per-field-confidence-thresholds, inline-pre-validation-error, 422-exception-propagation]

key-files:
  created: []
  modified:
    - apps/mobile/lib/screens/document_scan/document_scan_screen.dart
    - apps/mobile/lib/screens/document_scan/extraction_review_screen.dart
    - apps/mobile/lib/services/document_parser/document_models.dart
    - apps/mobile/lib/services/document_service.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb

key-decisions:
  - "Per-field thresholds use static map with 0.80 default; salary >= 0.90, LPP capital >= 0.95"
  - "DocumentServiceException propagated from extractWithVision for 422, caught specifically in _tryVisionExtraction"
  - "Backend fallback source_text '[non fourni par l'extraction]' filtered out in UI display"
  - "Red fields get both highlighted border (error 0.3 opacity) AND text prompt, not just color"

patterns-established:
  - "Per-field confidence: _fieldThresholds map with _thresholdFor() lookup, fallback 0.80"
  - "Pre-validation error: inline warning card with _preValidationError/_preValidationHint state"
  - "422 propagation: DocumentServiceException rethrown from service, caught in screen with specific handler"

requirements-completed: [DOC-01, DOC-02, DOC-03, DOC-06]

# Metrics
duration: 8min
completed: 2026-04-06
---

# Phase 02 Plan 03: Flutter Capture and Review Screen Enhancement Summary

**Per-field confidence thresholds (salary 0.90, LPP 0.95), LPP 1e/coherence warning banners, source_text display, and 422 pre-validation error handling with 10 i18n keys in 6 languages**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-06T14:06:26Z
- **Completed:** 2026-04-06T14:14:30Z
- **Tasks:** 2
- **Files modified:** 18 (10 ARB + 4 Dart source + 4 generated l10n)

## Accomplishments
- Per-field confidence thresholds replace global 0.80: salary fields require >= 0.90, LPP capital fields require >= 0.95 (DOC-03)
- LPP 1e warning banner and cross-field coherence warning banners displayed on extraction_review_screen (DOC-04/05 frontend)
- Source text shown per field with italic "Source : " prefix, backend fallback text filtered (DOC-09 frontend)
- Non-financial document rejection (HTTP 422) displayed as friendly inline error card (DOC-10 frontend)
- Client-side file validation: 10MB max size and accepted format check before upload
- 10 new i18n keys added to all 6 ARB files with proper translations
- flutter analyze: 0 errors across all modified files

## Task Commits

Each task was committed atomically:

1. **Task 1: Add i18n keys + enhance document_scan_screen with pre-validation error display** - `198711c5` (feat)
2. **Task 2: Enhance extraction_review_screen with per-field thresholds, LPP/coherence warnings, source_text** - `e8cf158f` (feat)

**Plan metadata:** pending (docs: complete plan)

## Files Created/Modified
- `apps/mobile/lib/screens/document_scan/document_scan_screen.dart` - Pre-validation error display, 422 handling, file size/format validation
- `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart` - Per-field thresholds, LPP 1e warning, coherence warnings, source_text, confirm button i18n
- `apps/mobile/lib/services/document_parser/document_models.dart` - planType, planTypeWarning, coherenceWarnings on ExtractionResult
- `apps/mobile/lib/services/document_service.dart` - DocumentServiceException thrown on 422
- `apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb` - 10 new i18n keys each

## Decisions Made
- Per-field thresholds use a static map with 0.80 default -- keeps lookup O(1) and easily extensible for new field types
- DocumentServiceException rethrown from extractWithVision specifically for 422 -- all other errors still return null for graceful OCR fallback
- Backend source_text fallback "[non fourni par l'extraction]" is filtered out in UI -- no value in displaying it to user
- Red fields (below threshold) get both a highlighted border AND a text prompt ("Verifie cette valeur") -- accessible per DOC-03 spec (not color-only)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] DocumentService.extractWithVision returns null for all non-200, cannot distinguish 422**
- **Found during:** Task 1
- **Issue:** The existing extractWithVision method returned null for any non-200 status, making it impossible to detect 422 (non-financial doc) at the screen level
- **Fix:** Modified extractWithVision to throw DocumentServiceException for 422, with rethrow in catch block; other errors still return null
- **Files modified:** apps/mobile/lib/services/document_service.dart
- **Verification:** flutter analyze 0 errors; 422 handling tested via code path review
- **Committed in:** 198711c5

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to distinguish 422 from general failures. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All Flutter screens for document intelligence pipeline are enhanced
- Backend intelligence (plan type detection, coherence validation, source_text) is wired to UI
- Ready for Plan 04 (document_impact_screen enhancement) to complete the full flow
- Pattern established: per-field threshold map is extensible for new document types

---
*Phase: 02-intelligence-documentaire*
*Completed: 2026-04-06*
