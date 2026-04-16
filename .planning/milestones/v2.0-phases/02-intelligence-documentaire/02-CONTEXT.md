# Phase 2: Intelligence Documentaire - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can photograph or upload a Swiss financial document (certificat LPP, certificat de salaire, attestation 3a, police d'assurance) and see their profile instantly enriched with extracted data they confirm. Original documents deleted immediately after extraction. Audit log retained.

Requirements: DOC-01, DOC-02, DOC-03, DOC-04, DOC-05, DOC-06, DOC-07, DOC-08, DOC-09, DOC-10, COMP-04

</domain>

<decisions>
## Implementation Decisions

### Document Capture & Input
- Capture methods: camera primary (quick photo), gallery/screenshot secondary, PDF upload tertiary — per DOC-01 and "balance-moi le print screen" philosophy
- Camera implementation: `image_picker` package (existing Flutter standard) — camera for live capture, gallery for screenshots
- PDF handling: `file_picker` for PDF selection → send to backend as multipart upload
- Pre-extraction validation (DOC-10): client-side file type check (image/pdf only) + file size (<10MB). Backend: Claude Vision classifies document type → reject non-financial with friendly error message

### LLM Extraction & Confidence
- Extraction engine: Claude Vision API via existing `document_vision_service.py` with structured JSON output schema for Swiss financial document types
- Per-field confidence display (DOC-03): color-coded badges — green (≥0.90), yellow (0.70-0.89), red (<0.70). Red fields get inline verification prompt on extraction_review_screen
- LPP plan type detection (DOC-04): dedicated extraction step — detect "légal/surobligatoire/1e" from document header BEFORE parsing financial fields. 1e plans trigger capital-only projection with explicit warning
- Cross-field coherence (DOC-05): backend validates `obligatoire + surobligatoire ≈ total` (±5% tolerance) — flags 10x hallucination errors. Coherence failures shown as warning banner on review screen

### Profile Enrichment & Privacy
- Confirmation UX (DOC-06): existing `extraction_review_screen.dart` — shows extracted fields as editable cards with confidence badges, user confirms each → ProfileEnrichmentDiff → CoachProfile. Never direct writes.
- Document deletion (DOC-08, COMP-04): delete original image in `finally` block (covers error paths). Retain audit log with: timestamp, document type, field count, confidence scores — NO image data. Audit log retained 2 years.
- Source text traceability (DOC-09): each extracted field carries `source_text` (exact passage from document) — stored temporarily for user verification on review screen, deleted with original document
- Post-extraction premier éclairage (DOC-07): immediate coach message with insight from newly extracted data — reuse 4-layer engine from Phase 1 with document-specific context injection

### Claude's Discretion
- Exact structured JSON schema for each document type (LPP, salary certificate, 3a, insurance)
- Camera overlay UX (crop guide, document alignment hints)
- Audit log storage format and location
- Error handling for corrupted/unreadable documents
- Extraction retry logic for low-confidence results

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `screens/document_scan/document_scan_screen.dart` — existing capture screen (likely needs enhancement)
- `screens/document_scan/extraction_review_screen.dart` — existing review screen for extracted fields
- `screens/document_scan/document_impact_screen.dart` — impact display (may be reusable for post-extraction insight)
- `screens/document_scan/avs_guide_screen.dart` — AVS document guide
- `services/backend/app/services/document_vision_service.py` — Claude Vision extraction (exists but NO registered FastAPI endpoint)
- `services/backend/app/services/document_parser/` — document parsing utilities
- `services/backend/app/services/docling/` — document intelligence utilities
- `providers/coach_profile_provider.dart` — profile enrichment target

### Established Patterns
- `image_picker` likely already in pubspec.yaml
- GoRouter navigation, Provider state management
- Backend pure functions with Pydantic v2 schemas
- ComplianceGuard for all output validation
- 4-layer insight engine (established in Phase 1)

### Integration Points
- Backend: need to register endpoint for `document_vision_service.py` (noted as first task in STATE.md)
- Frontend: capture screen → backend extraction → review screen → profile enrichment → coach insight
- CoachProfile: ProfileEnrichmentDiff pattern for safe field updates
- ComplianceGuard: validate extraction insights before showing to user

</code_context>

<specifics>
## Specific Ideas

- STATE.md notes: "document_vision_service.py exists but has no registered FastAPI endpoint — wiring is the first task"
- STATE.md notes: "LPP caisse template coverage estimated at 60% — actual coverage depends on real user documents"
- Document types to support: certificat LPP, certificat de salaire, attestation 3a, police d'assurance
- Confidence thresholds from DOC-03: salary ≥ 0.90, LPP capital ≥ 0.95
- nLPD compliance: original images MUST be deleted immediately, even on error paths

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
