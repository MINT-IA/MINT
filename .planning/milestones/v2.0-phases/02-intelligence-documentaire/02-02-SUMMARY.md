---
phase: 02-intelligence-documentaire
plan: 02
subsystem: api
tags: [claude-vision, lpp-plan-type, coherence-validation, source-text, document-extraction]

# Dependency graph
requires:
  - phase: 02-intelligence-documentaire
    plan: 01
    provides: classify_document(), VisionExtractionResponse schema, extract_with_vision()
provides:
  - LppPlanType enum (legal, surobligatoire, 1e) for plan type classification
  - detect_lpp_plan_type() pre-extraction Vision call
  - validate_lpp_coherence() cross-field validation with 5% tolerance and 10x detection
  - Source text enforcement (DOC-09) degrading missing source_text to low confidence
  - plan_type, plan_type_warning, coherence_warnings fields on VisionExtractionResponse
affects: [02-intelligence-documentaire, 06-qa-profond]

# Tech tracking
tech-stack:
  added: []
  patterns: [pre-extraction-classification, coherence-validation, source-text-enforcement, field-suppression-for-1e]

key-files:
  created:
    - services/backend/tests/test_lpp_plan_type.py
  modified:
    - services/backend/app/schemas/document_scan.py
    - services/backend/app/services/document_vision_service.py
    - services/backend/tests/test_document_parser.py

key-decisions:
  - "1e plans suppress tauxConversion from extraction prompt (not just from response) to avoid hallucinated conversion rates"
  - "Missing source_text degrades confidence to low rather than rejecting field (user-friendly, DOC-09)"
  - "Default plan type on error is surobligatoire (safest middle ground -- not 1e which suppresses conversion, not legal which might miss suroblig)"
  - "10x error detection uses 5x/0.2x thresholds for disproportionate total detection"

patterns-established:
  - "Pre-extraction classification: detect plan characteristics BEFORE building extraction prompt"
  - "Field suppression: remove fields from extraction prompt when plan type makes them invalid"
  - "Coherence validation: cross-field checks after extraction with confidence downgrade on failure"
  - "Source text enforcement: every extracted field must have traceable source_text or gets degraded"

requirements-completed: [DOC-04, DOC-05, DOC-09]

# Metrics
duration: 5min
completed: 2026-04-06
---

# Phase 02 Plan 02: LPP Plan Type Detection and Coherence Validation Summary

**LPP plan type detection (legal/surobligatoire/1e) with conversion rate suppression for 1e plans, cross-field coherence validation with 5% tolerance and 10x error detection, and mandatory source_text enforcement**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-06T14:00:04Z
- **Completed:** 2026-04-06T14:04:42Z
- **Tasks:** 2
- **Files modified:** 4
- **Tests added:** 27 new tests (15 plan type + 12 coherence)

## Accomplishments
- 1e plans detected BEFORE extraction, preventing catastrophic 6.8% conversion rate application to investment plans (DOC-04)
- Cross-field coherence catches >5% mismatch between obligatoire + surobligatoire vs total, with specific 10x hallucination detection (DOC-05)
- Every extracted field must carry non-empty source_text or gets degraded to low confidence (DOC-09)
- All 103 tests pass across both test files, 0 regressions on existing 119 document-related tests

## Task Commits

Each task was committed atomically:

1. **Task 1: LPP plan type detection (DOC-04)** - `9bf857a4` (test RED) + `6b8a7e63` (feat GREEN)
2. **Task 2: Cross-field coherence validation (DOC-05)** - `10449691` (test GREEN -- implementation done in Task 1)

**Plan metadata:** pending (docs: complete plan)

_TDD tasks: RED commit for failing tests, GREEN commit for passing implementation_

## Files Created/Modified
- `services/backend/app/schemas/document_scan.py` - LppPlanType enum + plan_type/plan_type_warning/coherence_warnings on VisionExtractionResponse
- `services/backend/app/services/document_vision_service.py` - detect_lpp_plan_type(), validate_lpp_coherence(), source_text enforcement in extract_with_vision()
- `services/backend/tests/test_lpp_plan_type.py` - 15 tests for plan type detection, conversion suppression, source_text enforcement
- `services/backend/tests/test_document_parser.py` - 12 tests for cross-field coherence validation

## Decisions Made
- 1e plans suppress tauxConversion from the extraction prompt itself (not just post-processing) to prevent Claude from hallucinating a conversion rate
- Missing source_text degrades to low confidence with placeholder text rather than rejecting (DOC-09: user-friendly degradation)
- Default plan type on API error: surobligatoire (safest middle ground)
- 10x error detection thresholds: total > 5x or total < 0.2x of (oblig + suroblig)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- LPP plan type detection and coherence validation ready for frontend consumption
- VisionExtractionResponse now carries plan_type, plan_type_warning, coherence_warnings
- Frontend can display appropriate warnings for 1e plans and coherence mismatches
- Pattern established: future document types can add similar pre-extraction classification steps

---
*Phase: 02-intelligence-documentaire*
*Completed: 2026-04-06*
