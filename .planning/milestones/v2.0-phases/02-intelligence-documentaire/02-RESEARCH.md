# Phase 2: Intelligence Documentaire - Research

**Researched:** 2026-04-06
**Domain:** Document capture, LLM Vision extraction, profile enrichment, privacy compliance
**Confidence:** HIGH

## Summary

Phase 2 builds on a **substantially complete** document pipeline. The backend `document_vision_service.py` already calls Claude Vision API with structured JSON extraction for 12+ Swiss financial document types. The frontend `document_scan_screen.dart` already captures via camera/gallery/PDF, calls Vision extraction with OCR fallback, and `extraction_review_screen.dart` displays extracted fields with confidence badges and routes to `CoachProfileProvider.updateFromLpp/Avs/Tax/SalaryExtraction()`. Backend endpoints exist at `/api/v1/documents/extract-vision` and `/api/v1/documents/scan-confirmation`.

The primary work is **enhancement and hardening**, not greenfield: (1) LPP plan type detection (legal/surobligatoire/1e) before conversion rate extraction, (2) cross-field coherence validation with DOC-05 tolerance rules, (3) per-field confidence thresholds per DOC-03 (salary >= 0.90, LPP capital >= 0.95), (4) guaranteed document deletion in `finally` blocks with audit logging per COMP-04/nLPD, (5) pre-extraction document classification to reject non-financial documents (DOC-10), (6) source_text traceability as mandatory field (DOC-09), and (7) post-extraction premier eclairage generation (DOC-07).

**Primary recommendation:** Wire existing components with focused enhancements -- do NOT rewrite. The pipeline is 80% functional. Focus on the 6 gaps listed above, each mapping to a specific requirement.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Capture methods: camera primary (image_picker), gallery/screenshot secondary, PDF upload tertiary (file_picker) -- per DOC-01
- Extraction engine: Claude Vision API via existing `document_vision_service.py` with structured JSON output schema
- Per-field confidence display (DOC-03): color-coded badges -- green (>=0.90), yellow (0.70-0.89), red (<0.70). Red fields get inline verification prompt
- LPP plan type detection (DOC-04): dedicated extraction step -- detect "legal/surobligatoire/1e" from document header BEFORE parsing financial fields. 1e plans trigger capital-only projection with explicit warning
- Cross-field coherence (DOC-05): backend validates `obligatoire + surobligatoire ~ total` (+-5% tolerance) -- flags 10x hallucination errors
- Confirmation UX (DOC-06): existing `extraction_review_screen.dart` -- shows extracted fields as editable cards, user confirms each -> ProfileEnrichmentDiff -> CoachProfile. Never direct writes.
- Document deletion (DOC-08, COMP-04): delete original image in `finally` block (covers error paths). Retain audit log with: timestamp, document type, field count, confidence scores -- NO image data. Audit log retained 2 years.
- Source text traceability (DOC-09): each extracted field carries `source_text` -- stored temporarily for user verification, deleted with original document
- Post-extraction premier eclairage (DOC-07): immediate coach message with insight from newly extracted data -- reuse 4-layer engine from Phase 1
- Pre-extraction validation (DOC-10): client-side file type check + backend document classification via Claude Vision -> reject non-financial with friendly error

### Claude's Discretion
- Exact structured JSON schema for each document type (LPP, salary certificate, 3a, insurance)
- Camera overlay UX (crop guide, document alignment hints)
- Audit log storage format and location
- Error handling for corrupted/unreadable documents
- Extraction retry logic for low-confidence results

### Deferred Ideas (OUT OF SCOPE)
None
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOC-01 | Camera, gallery, PDF capture | Existing `document_scan_screen.dart` with `image_picker` + `file_picker` -- needs insurance_policy type added to supported types |
| DOC-02 | LLM Vision extracts structured fields from Swiss docs | Existing `document_vision_service.py` + `/extract-vision` endpoint -- fully wired |
| DOC-03 | Per-field confidence thresholds (salary >= 0.90, LPP >= 0.95) | Existing confidence display in `extraction_review_screen.dart` -- needs threshold enforcement logic added |
| DOC-04 | LPP plan type detection (legal/surobligatoire/1e) | NEW: add `planType` extraction step in Vision prompt BEFORE financial fields; 1e warning logic |
| DOC-05 | Cross-field coherence checks (oblig + suroblig ~ total) | Partially exists in `lpp_certificate_parser.py` `_cross_validate_totals()` -- need to add to Vision extraction path |
| DOC-06 | ProfileEnrichmentDiff with user confirmation | Existing `extraction_review_screen.dart` -> `CoachProfileProvider.updateFrom*()` methods |
| DOC-07 | Post-extraction premier eclairage | NEW: trigger 4-layer insight engine with document-specific context after profile enrichment |
| DOC-08 | Document image deletion (nLPD) with audit log | Partial: `_cleanupTempFile()` exists but not in `finally`; audit log structure needs creation |
| DOC-09 | Mandatory source_text field | Already in `ExtractedFieldConfirmation.source_text` -- need to enforce non-null in extraction |
| DOC-10 | Pre-extraction validation rejects non-financial docs | NEW: add document classification step before extraction |
| COMP-04 | Document images deleted in `finally` blocks, audit log retained 2 years | Enhancement to existing deletion flow + new audit model |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Backend = source of truth** for constants and formulas. Flutter mirrors, never invents.
- **Pure functions** for all calculations (deterministic, testable).
- **Pydantic v2**: `ConfigDict(populate_by_name=True)`, `alias_generator = to_camel`.
- **All user-facing strings** in 6 ARB files via `AppLocalizations.of(context)!.key`.
- **GoRouter** navigation, **Provider** state management.
- **MintColors.\*** -- never hardcode hex.
- **ComplianceGuard** for all output validation.
- **Disclaimer, sources, premier_eclairage, alertes** required in every calculator/service output.
- **Privacy**: Never log identifiable data.
- **No-Advice, No-Promise, No-Ranking** compliance rules.
- Branch flow: feature/* -> dev -> staging -> main. Never push to staging/main directly.
- Before any code modification: confirm feature branch, check git status.
- Minimum 10 unit tests per service file.

## Standard Stack

### Core (Already Installed)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `anthropic` (Python) | 0.86.0 | Claude Vision API calls | Already used for coach, verified in requirements.txt [VERIFIED: pip show] |
| `image_picker` (Flutter) | ^1.1.2 | Camera + gallery capture | Already in pubspec.yaml [VERIFIED: pubspec.yaml] |
| `file_picker` (Flutter) | ^8.0.0 | PDF file selection | Already in pubspec.yaml [VERIFIED: pubspec.yaml] |
| `google_mlkit_text_recognition` (Flutter) | ^0.15.0 | OCR fallback (offline) | Already in pubspec.yaml [VERIFIED: pubspec.yaml] |
| Flutter | 3.41.4 | Mobile framework | Already installed [VERIFIED: flutter --version] |
| FastAPI | existing | Backend framework | Already configured [VERIFIED: codebase] |

### No New Dependencies Required
This phase requires **zero new packages**. All capture, extraction, and profile enrichment infrastructure exists. The work is enhancement of existing code.

## Architecture Patterns

### Existing Pipeline (Verified in Codebase)
```
Flutter (capture)                    Backend (extraction)
─────────────────                    ────────────────────
document_scan_screen.dart            documents.py endpoints
  ├─ image_picker (camera/gallery)     ├─ POST /extract-vision
  ├─ file_picker (PDF)                 │    └─ document_vision_service.py
  ├─ _tryVisionExtraction()            │         └─ Claude Vision API
  │    └─ DocumentService.extractWithVision()     └─ _validate_fields()
  ├─ MLKit OCR fallback                │
  └─ _processOcrText()                 ├─ POST /scan-confirmation
       └─ local parsers                │    └─ stores audit in DocumentModel
            └─ lpp_certificate_parser  │
                                       └─ POST /document-parser/parse
extraction_review_screen.dart               └─ OCR text parsers
  ├─ confidence badges (existing)
  ├─ field editing (existing)
  └─ _onConfirmAll()
       ├─ CoachProfileProvider.updateFrom*()
       ├─ DocumentService.sendScanConfirmation()
       └─ context.push('/scan/impact')
```

### Pattern 1: Vision-First with OCR Fallback
**What:** Claude Vision API is the primary extraction path. MLKit OCR is fallback for offline/failure. [VERIFIED: `_processImageFile()` in document_scan_screen.dart lines 467-514]
**When to use:** Always for image-based documents. PDF uploads may use docling parser directly.
**Key insight:** Vision already returns `source_text` per field in JSON response schema. The backend prompt explicitly requests it.

### Pattern 2: ProfileEnrichmentDiff via CoachProfileProvider
**What:** Extraction review screen calls `CoachProfileProvider.updateFromLpp/Avs/Tax/SalaryExtraction()` methods which map extracted fields to profile fields and persist. [VERIFIED: extraction_review_screen.dart lines 494-559]
**When to use:** After user confirms extracted fields on review screen. Never direct writes.
**Key insight:** Couple support already exists -- `_askWhoseDocument()` dialog for LPP and salary certificates.

### Pattern 3: Backend Audit Trail via DocumentModel
**What:** `/scan-confirmation` endpoint creates a `DocumentModel` record with scan metadata (no image data). [VERIFIED: documents.py line 689-712]
**When to use:** After user confirms extraction. Stores: document_type, confidence, fields_found, extracted_fields dict, extraction_method.
**Key insight:** This is the audit log -- needs enhancement for COMP-04 (2-year retention, explicit deletion tracking).

### Anti-Patterns to Avoid
- **Storing image bytes anywhere** -- nLPD violation. Images must be deleted in `finally` blocks.
- **Bypassing extraction_review_screen** -- Never auto-inject extracted data into profile. User MUST confirm.
- **Duplicating parsers** -- Backend `document_vision_service.py` and Flutter local parsers serve different paths (Vision vs OCR). Don't merge them.
- **Making Vision call synchronous without timeout** -- Already has 30s timeout [VERIFIED: document_vision_service.py line 191]. Keep it.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Swiss number parsing | Custom parser | `parse_swiss_number()` in `lpp_certificate_parser.py` | Already handles apostrophe separators, comma vs dot, edge cases [VERIFIED] |
| Cross-field validation | New validator | `_cross_validate_totals()` in `lpp_certificate_parser.py` | Already validates oblig + suroblig ~ total with 5% tolerance [VERIFIED] |
| Confidence scoring | Custom scorer | `extraction_confidence_scorer.py` | Field-impact-weighted scoring with per-document-type weights [VERIFIED] |
| Document type detection | New classifier | `_detect_document_type()` in `documents.py` | Keyword-based detection exists; enhance rather than replace |
| Profile enrichment | Direct writes | `CoachProfileProvider.updateFrom*()` | 4 methods already map extraction fields to profile fields [VERIFIED] |
| Image capture | Custom camera | `image_picker` package | Platform-handled, already configured [VERIFIED] |

**Key insight:** 80% of this phase's functionality is already built. The risk is over-engineering rather than under-engineering.

## Common Pitfalls

### Pitfall 1: Image Bytes Leaking to Logs/Storage
**What goes wrong:** Base64 image data accidentally logged, stored in DB, or retained in memory after extraction.
**Why it happens:** Error paths skip cleanup; logging captures full request bodies.
**How to avoid:** `finally` block for deletion. Never log `image_base64` field. Add explicit log filtering.
**Warning signs:** Large payloads in backend logs, growing disk usage.

### Pitfall 2: LPP Plan Type Confusion (Legal vs Surobligatoire vs 1e)
**What goes wrong:** Applying 6.8% conversion rate to 1e plan assets, massively inflating projected pension.
**Why it happens:** 1e plans have NO guaranteed conversion rate -- assets are pure capital. Most caisses don't print "plan 1e" prominently.
**How to avoid:** DOC-04 requires detecting plan type BEFORE conversion rate extraction. If 1e detected, suppress conversion rate field and show capital-only projection with explicit warning.
**Warning signs:** Conversion rates < 5% on large surobligatoire portions; very high surobligatoire vs obligatoire ratio.

### Pitfall 3: 10x Hallucination Errors from Claude Vision
**What goes wrong:** Claude reads "CHF 35'000" as "CHF 350'000" -- a 10x error that passes individual field range checks.
**Why it happens:** Swiss number formatting with apostrophes, poor image quality, ambiguous OCR.
**How to avoid:** DOC-05 cross-field coherence: `obligatoire + surobligatoire ~ total` (+-5%). If totals don't match, flag ALL three fields for review.
**Warning signs:** Individual fields in valid ranges but sum doesn't match; overall confidence high despite logical inconsistency.

### Pitfall 4: DocumentType Enum Mismatch Frontend/Backend
**What goes wrong:** Frontend sends `lppCertificate` but backend expects `lpp_certificate`.
**Why it happens:** Dart uses camelCase enums, Python uses snake_case.
**How to avoid:** Use existing `DocumentTypeBackend.backendValue` extension [VERIFIED: document_models.dart]. Already mapped correctly for existing types.
**Warning signs:** 400 errors from backend; "unsupported document type" responses.

### Pitfall 5: Missing `finally` Block on Image Deletion
**What goes wrong:** Extraction fails mid-way, original image stays on device/in memory.
**Why it happens:** Deletion code in happy path only, not in `finally`.
**How to avoid:** COMP-04 explicitly requires `finally` blocks. Current `_cleanupTempFile()` is called in `finally` of `_processImageFile()` [VERIFIED: document_scan_screen.dart line 513] but base64 encoding happens before that -- verify the base64 string is also cleared.
**Warning signs:** Growing temp directory size; images accessible after failed extraction.

### Pitfall 6: Confidence Threshold Mismatch Between DOC-03 Spec and Existing Code
**What goes wrong:** Existing code uses 0.80 as green threshold [VERIFIED: extraction_review_screen.dart line 132], but DOC-03 requires salary >= 0.90, LPP capital >= 0.95.
**Why it happens:** Requirements are per-field, existing code uses a global threshold.
**How to avoid:** Implement per-field-type confidence thresholds in extraction review, not a single global cutoff.
**Warning signs:** Salary fields showing green at 0.85 when spec requires 0.90.

## Code Examples

### Existing Vision Extraction Call (Backend)
```python
# Source: services/backend/app/services/document_vision_service.py (verified in codebase)
# Already functional -- Claude Vision extraction with structured JSON output
result = extract_with_vision(
    image_base64=base64_image,
    doc_type=DocumentType.lpp_certificate,
    canton="VS",
    language_hint="fr",
)
# Returns VisionExtractionResponse with extracted_fields, overall_confidence, source_text per field
```

### Existing Profile Enrichment (Flutter)
```dart
// Source: apps/mobile/lib/screens/document_scan/extraction_review_screen.dart (verified)
// Already functional -- maps extraction to profile update
switch (widget.result.documentType) {
  case DocumentType.lppCertificate:
    if (isPartnerDoc) {
      await coachProvider.updateFromPartnerLppExtraction(_fields);
    } else {
      await coachProvider.updateFromLppExtraction(_fields);
    }
  case DocumentType.avsExtract:
    await coachProvider.updateFromAvsExtraction(_fields);
  // ... other types
}
```

### NEW: LPP Plan Type Detection (to implement)
```python
# Recommended: Add planType as first extraction step in Vision prompt
# Before financial field extraction, detect plan type from document header

LPP_PLAN_TYPE_PROMPT = """
Avant d'extraire les champs financiers, identifie le type de plan:
- "legal": plan minimum LPP (taux conversion 6.8%)
- "surobligatoire": plan enveloppant avec part surobligatoire
- "1e": plan 1e (investissement individuel, PAS de taux de conversion garanti)

Indices pour detecter un plan 1e:
- Mention "plan 1e" ou "plan de prevoyance 1e"
- Pas de taux de conversion fixe
- Reference a des "strategies d'investissement" individuelles
- Part surobligatoire >> part obligatoire avec choix de fonds

Reponds: {"plan_type": "legal|surobligatoire|1e", "confidence": "high|medium|low"}
"""
```

### NEW: Document Deletion with Audit Log (to implement)
```python
# Recommended: Audit log model for COMP-04
class DocumentAuditLog(Base):
    __tablename__ = "document_audit_logs"
    id: Mapped[str] = mapped_column(primary_key=True)
    user_id: Mapped[str]  # hashed, not raw
    document_type: Mapped[str]
    field_count: Mapped[int]
    overall_confidence: Mapped[float]
    extraction_method: Mapped[str]
    created_at: Mapped[datetime]
    deleted_at: Mapped[datetime]  # when image was deleted
    # NO image data, NO field values, NO source_text
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| MLKit OCR only | Claude Vision primary, MLKit fallback | Already implemented | 80%+ accuracy on Swiss docs vs ~50% OCR [ASSUMED] |
| Global confidence threshold (0.80) | Per-field-type thresholds (DOC-03) | This phase | Salary >= 0.90, LPP capital >= 0.95 |
| No plan type detection | LPP plan type (legal/surob/1e) first | This phase | Prevents 1e conversion rate errors |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Claude Vision accuracy on Swiss financial docs is ~80%+ | State of the Art | Low -- existing pipeline already uses it successfully |
| A2 | DocumentModel table has columns for audit fields (overall_confidence, extraction_method) | Architecture | Medium -- need to verify migration exists; columns seen in documents.py line 689-700 |
| A3 | 4-layer insight engine from Phase 1 is complete and reusable for DOC-07 | Phase Requirements | High -- if Phase 1 not complete, DOC-07 blocks |

## Open Questions

1. **Phase 1 completion status for DOC-07**
   - What we know: DOC-07 requires 4-layer insight engine from Phase 1
   - What's unclear: Whether Phase 1 premier eclairage is fully wired and tested
   - Recommendation: Verify Phase 1 completion before planning DOC-07 tasks

2. **Audit log retention enforcement**
   - What we know: COMP-04 requires 2-year retention of audit logs
   - What's unclear: Whether there's an existing cleanup/TTL mechanism for old records
   - Recommendation: Add `retained_until` field to audit log; implement cleanup job later (not blocking for v2.0)

3. **PDF extraction path**
   - What we know: Backend has `docling` parser for PDFs + Vision endpoint for images
   - What's unclear: Should PDF uploads go through Vision (image of each page) or docling text extraction?
   - Recommendation: PDFs -> docling text extraction (existing); images -> Claude Vision (existing). Two paths, not one.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Claude API (anthropic) | Vision extraction | Yes | 0.86.0 | MLKit OCR fallback |
| Flutter | Mobile app | Yes | 3.41.4 | -- |
| image_picker | Camera capture | Yes | ^1.1.2 | -- |
| file_picker | PDF upload | Yes | ^8.0.0 | -- |
| google_mlkit_text_recognition | OCR fallback | Yes | ^0.15.0 | -- |
| FastAPI | Backend API | Yes | existing | -- |
| SQLAlchemy | Audit log storage | Yes | existing | -- |

**Missing dependencies with no fallback:** None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework (Backend) | pytest (existing) |
| Framework (Flutter) | flutter_test (existing) |
| Config file | services/backend/pytest.ini + apps/mobile/pubspec.yaml |
| Quick run (backend) | `python3 -m pytest services/backend/tests/test_document_scan.py -x -q` |
| Quick run (flutter) | `flutter test test/screens/document_scan_screen_test.dart` |
| Full suite | `python3 -m pytest services/backend/tests/ -q && cd apps/mobile && flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOC-01 | Camera/gallery/PDF capture | widget test | `flutter test test/screens/document_scan_screen_test.dart` | Yes |
| DOC-02 | Vision extraction of Swiss docs | unit test | `pytest tests/test_document_scan.py -x` | Yes (schema tests) |
| DOC-03 | Per-field confidence thresholds | unit test | `pytest tests/test_document_scan.py -x` | Yes (partial) |
| DOC-04 | LPP plan type detection | unit test | `pytest tests/test_lpp_plan_type.py -x` | No -- Wave 0 |
| DOC-05 | Cross-field coherence | unit test | `pytest tests/test_document_parser.py -x` | Yes (LPP parser) |
| DOC-06 | ProfileEnrichmentDiff confirmation | widget test | `flutter test test/providers/coach_profile_provider_tax_extraction_test.dart` | Yes (tax only) |
| DOC-07 | Post-extraction premier eclairage | integration test | `pytest tests/test_premier_eclairage_doc.py -x` | No -- Wave 0 |
| DOC-08 | Image deletion with audit log | unit test | `pytest tests/test_document_audit.py -x` | No -- Wave 0 |
| DOC-09 | Mandatory source_text | unit test | `pytest tests/test_document_scan.py -x` | Partial (schema) |
| DOC-10 | Pre-extraction validation | unit test | `pytest tests/test_document_classification.py -x` | No -- Wave 0 |
| COMP-04 | Finally-block deletion | unit test | `pytest tests/test_document_audit.py -x` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `pytest tests/test_document_scan.py tests/test_document_parser.py -x -q`
- **Per wave merge:** Full backend + flutter test suite
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `tests/test_lpp_plan_type.py` -- covers DOC-04 (plan type detection logic)
- [ ] `tests/test_document_audit.py` -- covers DOC-08, COMP-04 (audit log, finally-block deletion)
- [ ] `tests/test_document_classification.py` -- covers DOC-10 (non-financial document rejection)
- [ ] `tests/test_premier_eclairage_doc.py` -- covers DOC-07 (post-extraction insight generation)
- [ ] `test/providers/coach_profile_provider_lpp_extraction_test.dart` -- covers DOC-06 for LPP (only tax exists)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | Existing `require_current_user` on all document endpoints [VERIFIED] |
| V3 Session Management | No | Handled by existing auth layer |
| V4 Access Control | Yes | Document owner check: `row.user_id != str(_user.id)` [VERIFIED] |
| V5 Input Validation | Yes | File type validation, size limits, PDF magic bytes check [VERIFIED] |
| V6 Cryptography | No | No new crypto operations (profile encryption is separate) |

### Known Threat Patterns for Document Pipeline

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Image data persistence (nLPD) | Information Disclosure | `finally` block deletion, no image in DB, audit log without image [DOC-08/COMP-04] |
| EXIF metadata exposure | Information Disclosure | TODO(P2-W12) noted in codebase -- strip EXIF before Vision API call [ASSUMED: not yet implemented] |
| Base64 payload in logs | Information Disclosure | Never log `image_base64` field; truncate PII in log messages [VERIFIED: existing pattern] |
| Malicious PDF upload | Tampering | PDF magic bytes validation, 20MB size limit, MIME type check [VERIFIED: documents.py] |
| Hallucination in extraction | Spoofing | Cross-field coherence checks, per-field confidence thresholds, user confirmation [DOC-03/DOC-05] |
| Unauthorized document access | Elevation of Privilege | Owner check on GET/DELETE endpoints [VERIFIED: documents.py] |

## Sources

### Primary (HIGH confidence)
- Codebase: `services/backend/app/services/document_vision_service.py` -- full Vision extraction implementation
- Codebase: `services/backend/app/api/v1/endpoints/documents.py` -- all document endpoints including extract-vision
- Codebase: `apps/mobile/lib/screens/document_scan/document_scan_screen.dart` -- complete capture + Vision + OCR flow
- Codebase: `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart` -- review + profile enrichment
- Codebase: `services/backend/app/schemas/document_scan.py` -- Pydantic schemas for Vision API
- Codebase: `apps/mobile/lib/services/document_parser/document_models.dart` -- Flutter document types + models
- Codebase: `services/backend/app/services/document_parser/lpp_certificate_parser.py` -- OCR parser with cross-validation

### Secondary (MEDIUM confidence)
- `02-CONTEXT.md` -- user decisions from discuss phase
- `REQUIREMENTS.md` -- DOC-01 through DOC-10, COMP-04 specifications
- `STATE.md` -- blockers and accumulated context

### Tertiary (LOW confidence)
- None -- all findings verified against codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all packages already installed and verified in codebase
- Architecture: HIGH -- pipeline 80% built, patterns verified by code reading
- Pitfalls: HIGH -- derived from codebase analysis and requirement gaps
- Security: HIGH -- existing controls verified, gaps identified from requirements

**Research date:** 2026-04-06
**Valid until:** 2026-05-06 (stable -- no external dependency changes expected)
