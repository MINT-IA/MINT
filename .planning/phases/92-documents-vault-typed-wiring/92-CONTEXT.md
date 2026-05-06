# Phase 92: Documents Vault Typed Wiring — Context

**Gathered:** 2026-05-06
**Status:** Ready for planning
**Mode:** Auto-generated from architecture audit + walkthrough BUG #4 P0 marker

<domain>
## Phase Boundary

Vault upload pipeline (`documents_screen.dart` → `DocumentProvider.uploadDocument` → backend `/documents/upload` → `LPPCertificateExtractor`) returns `LppExtractedFields` typed object. The mobile screen displays « 15 fields extracted » UI but **never merges those fields into CoachProfile** — patrimoine card / projections stay empty. The /scan pipeline (`extraction_review_screen.dart`) DOES merge but uses `List<ExtractedField>` raw shape — incompatible API.

Phase 92 closes the BUG #4 P0 marker by adding a typed converter and wiring vault upload to merge fields into CoachProfile, invalidate confidence, and trigger Cap recompute. Plus harden idempotency to use SHA256 of file bytes (not random UUID per call).

</domain>

<decisions>
## Implementation Decisions

### DOCS-01 — Typed converter `updateFromLppExtractedFields(LppExtractedFields)`

- Add new method on `CoachProfileProvider` that takes the typed `LppExtractedFields` directly.
- Internally, convert each non-null field into the equivalent `ExtractedField` shape and call existing `updateFromLppExtraction(List<ExtractedField>)` — single source of truth, no duplication.
- 18 fields per `LppExtractedFields` (`avoirObligatoire`, `avoirSurobligatoire`, `avoirVieillesseTotal`, `salaireAssure`, `salaireAvs`, `deductionCoordination`, `tauxConversion*`, `renteInvalidite`, `capitalDeces`, `renteConjoint`, `renteEnfant`, `rachatMaximum`, `cotisationEmploye`, `cotisationEmployeur`, `remunerationRate`).

### DOCS-02 — Wire vault upload screen

- `documents_screen.dart:_pickAndUpload` calls the new converter post-upload.
- After merge, invalidate confidence (`coachProvider.invalidateConfidence()` or equivalent — discover in code).
- Trigger Cap recompute via `MintStateProvider` if the patrimoine changed materially.

### DOCS-03 — Idempotency hardening

- Backend `/documents/upload` already supports `Idempotency-Key` header (`documents.py:415-420`).
- Currently `document_service.dart:950` regenerates a fresh UUID per call → no real dedup on retries.
- Fix: client computes SHA256 of file bytes BEFORE upload, uses that as Idempotency-Key. Same file = same key = backend dedupe via `_idem.lookup_by_key`.

### Claude's discretion

- The converter can be a free function in `document_service.dart` OR a method on `LppExtractedFields` itself OR a method on `CoachProfileProvider`. Prefer the third (encapsulates merge logic in the provider).
- Test : compute golden values from `services/backend/tests/test_extractor_julien_cpe_golden.py` golden file, assert post-upload CoachProfile contains those exact values within 1 CHF tolerance.

</decisions>

<code_context>
## Existing Code Insights

### Reusable assets

- `apps/mobile/lib/services/document_service.dart:90-200` — `LppExtractedFields` typed class with 18 fields + `toJson()`.
- `apps/mobile/lib/providers/coach_profile_provider.dart:1355` — `Future<void> updateFromLppExtraction(List<ExtractedField> fields)` already exists.
- `apps/mobile/lib/services/document_understanding_result.dart:164` — `class ExtractedField` (legacy) and `apps/mobile/lib/services/document_parser/document_models.dart:174` — current `ExtractedField`.
- `services/backend/app/api/v1/endpoints/documents.py:415-420` — Idempotency-Key check via `_idem.lookup_by_key()`.

### Established patterns

- All providers use `notifyListeners()` after profile mutation.
- Confidence is computed by `EnhancedConfidenceService` based on profile freshness — invalidating happens automatically when `dataTimestamps` updates (which `updateFromLppExtraction` does).
- SHA256 in Dart : `package:crypto` already in pubspec.

### Integration points

- New method on `CoachProfileProvider` — single integration point for both /scan and vault paths.
- `documents_screen.dart` — replace existing « visible-only » comment with real merge call.
- `document_service.dart:_uploadDocument` — change idempotency key from UUID to SHA256.

</code_context>

<specifics>
## Specific Ideas

- Converter approach must NOT duplicate the merge logic from `updateFromLppExtraction` — wrap it.
- Test against the actual `cpe_plan_maxi_julien.pdf` fixture used by backend extractor golden test.

</specifics>

<deferred>
## Deferred Ideas

- AVS extract integration (DocumentProvider already supports it for /scan ; defer vault wiring to v2.15)
- Tax declaration extract — defer
- Multiple-files batch upload — defer

</deferred>
