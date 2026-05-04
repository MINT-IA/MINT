# Phase 23: Document Scanner Pipeline - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning
**Mode:** Auto-generated from Gate 0 findings

<domain>
## Phase Boundary

Fix: document scanner shows "Analyse PDF indisponible" when user selects a PDF. The upload→parse→dossier→coach pipeline must work end-to-end.

Requirements: DOC-01 (PDF parses), DOC-02 (data in dossier), DOC-03 (coach references it)

Gate 0 finding: P0-5 — "Analyse PDF indisponible. Une erreur est survenue lors de l'analyse du document."

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All choices at Claude's discretion — this is a fix phase.

Key investigation areas:
- What service handles PDF parsing? (document_service.dart? backend endpoint?)
- Is it a URL 404? (v2.4 had double /api/v1 prefix bugs)
- Is OCR configured? (google_mlkit_text_recognition? backend PDF parser?)
- Where does parsed data go? (dossier? profile? coach_profile?)
- How does the coach access document data?

Key files to investigate:
- apps/mobile/lib/screens/documents/ — scanner UI
- apps/mobile/lib/services/document_service.dart — upload/parse logic
- services/backend/app/api/v1/endpoints/ — document-related endpoints

</decisions>

<code_context>
## Existing Code Insights

From memory: v2.4 fixed "5 Flutter→Backend URLs are 404 (double /api/v1 prefix bug in document_service)". Document scanner may have been partially fixed in v2.4.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — investigate root cause and fix the pipeline.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
