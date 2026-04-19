---
phase: 23-document-scanner-pipeline
plan: 01
subsystem: infra, api, ui
tags: [pdfplumber, docling, vision-api, consent, pdf-extraction, document-scanner]

requires:
  - phase: none
    provides: standalone fix for broken document scanner pipeline

provides:
  - "pdfplumber installed in production Docker image via docling extra"
  - "Consent auto-grant on first document upload (no more 403 block)"
  - "PDF handling for all document types (LPP, tax, AVS, salary, 3a)"
  - "Vision API fallback when Docling backend fails"

affects: [coach-profile, document-vault, premium-gate]

tech-stack:
  added: [pdfplumber (production via docling extra)]
  patterns: [consent-auto-grant-on-action, vision-api-pdf-fallback]

key-files:
  created: []
  modified:
    - services/backend/Dockerfile
    - services/backend/app/api/v1/endpoints/documents.py
    - services/backend/tests/test_consent_guards.py
    - apps/mobile/lib/screens/document_scan/document_scan_screen.dart

key-decisions:
  - "Auto-grant document_upload consent on first upload -- user's explicit action IS informed consent per nLPD"
  - "Vision API as PDF fallback -- when Docling backend unavailable, try Claude Vision with base64-encoded PDF bytes"
  - "Map DocumentType to VaultDocumentType via _toVaultType() for backend API compatibility"

patterns-established:
  - "Consent auto-grant: user action = consent (no hidden toggles blocking core features)"
  - "Vision API PDF fallback: try backend first, fall back to Claude Vision, then show error dialog"

requirements-completed: [DOC-01, DOC-02, DOC-03]

duration: 7min
completed: 2026-04-13
---

# Phase 23 Plan 01: Document Scanner Pipeline Summary

**Fix broken PDF scanner: Dockerfile installs pdfplumber via docling extra, consent auto-grants on upload, all doc types supported with Vision API fallback**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-13T18:14:25Z
- **Completed:** 2026-04-13T18:21:42Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Dockerfile now installs `.[rag,docling]` so pdfplumber is available in production (was missing, causing 503)
- Consent gate auto-grants `document_upload` on first upload instead of returning 403 (Gate 0 P0-5 root cause)
- PDF import works for ALL document types (LPP, tax declaration, AVS extract, salary, 3a) not just LPP
- Vision API fallback added when Docling backend parsing fails -- tries Claude Vision with PDF bytes before showing error

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix backend PDF pipeline -- Dockerfile + consent gate** - `c681542f` (fix)
2. **Task 2: Fix Flutter PDF handling -- all doc types + Vision API fallback** - `ea1ae4dd` (feat)

## Files Created/Modified
- `services/backend/Dockerfile` - Added `.[docling]` extra to pip install, added pdfplumber version verification
- `services/backend/app/api/v1/endpoints/documents.py` - Consent auto-grant instead of 403 HTTPException
- `services/backend/tests/test_consent_guards.py` - Updated 3 tests to reflect auto-grant behavior
- `apps/mobile/lib/screens/document_scan/document_scan_screen.dart` - Broadened PDF handling to all types, added Vision API fallback, added _toVaultType mapper, fixed duplicate import

## Decisions Made
- Auto-grant consent on user's explicit upload action per nLPD art. 6 al. 7 -- blocking behind hidden toggle was creating broken UX
- Vision API as PDF fallback provides resilience when backend Docling is unavailable
- _toVaultType() mapper cleanly maps scan-screen DocumentType enum to backend VaultDocumentType enum

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated consent guard tests to match new auto-grant behavior**
- **Found during:** Task 1 (backend verification)
- **Issue:** 3 tests expected 403 on missing consent, but we changed to auto-grant
- **Fix:** Rewrote test_upload_blocked_without_document_upload_consent to test_upload_auto_grants_consent_on_first_use, merged two 403-expectation tests into test_upload_auto_grants_even_after_revoke
- **Files modified:** services/backend/tests/test_consent_guards.py
- **Verification:** All 13 consent guard tests pass, full suite 5396 passed
- **Committed in:** c681542f (Task 1 commit)

**2. [Rule 1 - Bug] Fixed pre-existing duplicate import in document_scan_screen.dart**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** Duplicate `import 'package:mint_mobile/services/navigation/safe_pop.dart'` on lines 2 and 4
- **Fix:** Removed duplicate import line
- **Files modified:** apps/mobile/lib/screens/document_scan/document_scan_screen.dart
- **Verification:** flutter analyze shows 0 issues
- **Committed in:** ea1ae4dd (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking test update, 1 pre-existing bug)
**Impact on plan:** Both necessary for correctness. No scope creep.

## Issues Encountered
None -- plan executed cleanly.

## User Setup Required
None -- no external service configuration required.

## Next Phase Readiness
- Document scanner pipeline is fixed end-to-end
- Manual verification needed: select PDF on device, confirm extraction review screen appears
- Backend tests all green (5396 passed), Flutter analyze clean (0 issues)

---
*Phase: 23-document-scanner-pipeline*
*Completed: 2026-04-13*
