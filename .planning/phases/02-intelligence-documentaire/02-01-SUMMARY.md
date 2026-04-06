---
phase: 02-intelligence-documentaire
plan: 01
subsystem: api
tags: [claude-vision, document-classification, audit-log, nlpd, sqlalchemy, privacy]

# Dependency graph
requires:
  - phase: 01-le-parcours-parfait
    provides: Auth flow and user model for current_user dependency
provides:
  - DocumentAuditLog model for nLPD-compliant extraction audit trail
  - classify_document() pre-extraction classification via Claude Vision
  - DocumentClassificationResult schema
  - Hardened extract-vision endpoint with finally-block image deletion
affects: [02-intelligence-documentaire, 06-qa-profond]

# Tech tracking
tech-stack:
  added: []
  patterns: [finally-block-cleanup, sha256-user-hashing, fail-open-classification, audit-metadata-only]

key-files:
  created:
    - services/backend/app/models/document_audit.py
    - services/backend/tests/test_document_classification.py
    - services/backend/tests/test_document_audit.py
  modified:
    - services/backend/app/schemas/document_scan.py
    - services/backend/app/services/document_vision_service.py
    - services/backend/app/api/v1/endpoints/documents.py
    - services/backend/tests/test_document_scan.py

key-decisions:
  - "Fail-open classification: API errors return is_financial=True to avoid blocking legitimate users (T-02-05)"
  - "User ID stored as SHA-256 hash in audit log, never raw (nLPD privacy)"
  - "Module-import pattern for classify_document to enable clean test mocking"

patterns-established:
  - "Finally-block cleanup: image data cleared from memory even on error paths"
  - "Audit-metadata-only: no image data, no field values, no source text in audit models"
  - "SHA-256 user hashing: user_id_hash pattern for privacy-safe audit trails"

requirements-completed: [DOC-08, DOC-10, COMP-04]

# Metrics
duration: 8min
completed: 2026-04-06
---

# Phase 02 Plan 01: Document Pipeline Hardening Summary

**Pre-extraction classification via Claude Vision, DocumentAuditLog with SHA-256 hashed user IDs, and finally-block image deletion for nLPD compliance**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-06T13:50:14Z
- **Completed:** 2026-04-06T13:58:06Z
- **Tasks:** 2
- **Files modified:** 7
- **Tests added:** 24 new tests (43 total across 3 test files)

## Accomplishments
- Non-financial documents (receipts, selfies) rejected with friendly 422 before extraction runs (DOC-10)
- Every extraction attempt creates audit log with metadata only -- zero image data stored (DOC-08)
- Image data cleared in finally block even on error paths, with deleted_at timestamp (COMP-04)
- Fail-open classification: API errors or missing keys allow extraction to proceed (user-friendly)
- Full backend test suite passes: 4958 tests, 0 failures, 0 regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: Pre-extraction classification + audit log model** - `051f9cfe` (test RED) + `a411fb2d` (feat GREEN)
2. **Task 2: Wire classification + audit + finally-block into endpoint** - `80b2306d` (feat GREEN)

**Plan metadata:** pending (docs: complete plan)

_TDD tasks: RED commit for failing tests, GREEN commit for passing implementation_

## Files Created/Modified
- `services/backend/app/models/document_audit.py` - DocumentAuditLog SQLAlchemy model + create_audit_log() helper
- `services/backend/app/schemas/document_scan.py` - DocumentClassificationResult schema
- `services/backend/app/services/document_vision_service.py` - classify_document() with Claude Vision
- `services/backend/app/api/v1/endpoints/documents.py` - Hardened extract-vision with classification gate, audit, finally-block
- `services/backend/tests/test_document_classification.py` - 9 tests for classification logic
- `services/backend/tests/test_document_audit.py` - 10 tests for audit model
- `services/backend/tests/test_document_scan.py` - 6 new endpoint wiring tests (25 total)

## Decisions Made
- Fail-open classification on API errors (is_financial=True) -- better to attempt extraction than block user
- SHA-256 hashing of user_id in audit log -- never store raw user IDs per nLPD
- Module-import pattern (`import document_vision_service as dvs`) for testable mocking of classify_document
- 2-year retention period (730 days) for audit logs via retained_until default

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed test mocking for settings.ANTHROPIC_API_KEY**
- **Found during:** Task 1 (GREEN phase)
- **Issue:** Tests for classify_document failed because settings.ANTHROPIC_API_KEY was not set in test env, causing early return before mock was reached
- **Fix:** Added `@patch` for settings alongside Anthropic client mock in all classification tests
- **Files modified:** services/backend/tests/test_document_classification.py
- **Verification:** All 9 classification tests pass
- **Committed in:** a411fb2d

**2. [Rule 3 - Blocking] Fixed classify_document import pattern for testability**
- **Found during:** Task 2 (GREEN phase)
- **Issue:** Local `from ... import classify_document` inside `_classify_and_reject_if_needed` was not affected by `@patch` decorator
- **Fix:** Changed to module-level import pattern (`from app.services import document_vision_service as dvs`) so patch targets work correctly
- **Files modified:** services/backend/app/api/v1/endpoints/documents.py
- **Verification:** All 25 endpoint tests pass with mocked classification
- **Committed in:** 80b2306d

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes were necessary for test mocking to work correctly. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Document classification and audit infrastructure ready for subsequent plans
- extract-vision endpoint hardened with all three safety guarantees (DOC-08, DOC-10, COMP-04)
- Pattern established: future document endpoints can use classify_document + create_audit_log + finally-block cleanup

---
*Phase: 02-intelligence-documentaire*
*Completed: 2026-04-06*
