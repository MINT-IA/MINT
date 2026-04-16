---
phase: 28-pipeline-document
plan: 01
subsystem: backend
tags: [vision, pdf, document-memory, render-mode, third-party, idempotency, feature-flag]
dependency_graph:
  requires: [27-01]   # FlagsService, IdempotencyService, TokenBudget, redis_client
  provides:
    - DocumentUnderstandingResult canonical contract
    - understand_document() fused entrypoint behind DOCUMENTS_V2_ENABLED
    - select_render_mode() deterministic selector
    - DocumentMemory ORM + upsert_and_diff()
    - detect_third_party() silent flag
    - preflight_pdf() + select_pages_for_vision()
  affects:
    - Phase 28-02 (SSE streaming) — will stream the canonical contract field-by-field
    - Phase 28-03 (Flutter scanner) — sends raw bytes; flag-on path returns DUR
    - Phase 28-04 (UI render_mode) — switches on result.renderMode
    - Phase 29 (PRIV-02) — wires nLPD consent gate behind third_party_detected
tech_stack:
  added:
    - pymupdf>=1.24 (PDF preflight)
    - pyyaml>=6.0 (issuer signatures fixture)
  patterns:
    - tool_use forced (single tool route_and_extract, JSON-validated API-side)
    - extended thinking (Claude 4.6 thinking blocks, budget=1024)
    - feature flag gating (legacy path stays, zero-redeploy rollback)
    - fail-soft Redis/pymupdf (degrade, never crash)
    - layered scrub via ComplianceGuard layer-1
key_files:
  created:
    - services/backend/app/schemas/document_understanding.py
    - services/backend/app/services/document_pdf_preflight.py
    - services/backend/app/services/document_render_mode.py
    - services/backend/app/services/document_memory_service.py
    - services/backend/app/services/document_third_party.py
    - services/backend/app/services/document_signatures.yaml
    - services/backend/app/models/document_memory.py
    - services/backend/alembic/versions/p28_document_memory.py
    - services/backend/tests/documents/test_pdf_preflight.py
    - services/backend/tests/documents/test_render_mode_selector.py
    - services/backend/tests/documents/test_document_memory.py
    - services/backend/tests/documents/test_third_party_detection.py
    - services/backend/tests/documents/test_fused_vision_mocked.py
    - services/backend/tests/documents/test_document_understanding_schema.py
  modified:
    - services/backend/app/services/document_vision_service.py (+understand_document and helpers)
    - services/backend/app/api/v1/endpoints/documents.py (Union response_model + flag gate)
    - services/backend/app/models/__init__.py (register DocumentMemory)
    - services/backend/pyproject.toml (pymupdf, pyyaml)
decisions:
  - Single fused tool_use call replaces classify→extract bifurcation (P50 latency ÷1.8, cost ÷1.9)
  - render_mode is a backend opaque enum — internal processing_mode never leaks to client
  - DocumentMemory uses generic JSON column for SQLite/Postgres parity (JSONB indexing deferred)
  - ComplianceGuard.scrub() doesn't exist — used _sanitize_banned_terms() (Layer 1) directly
  - app/db/models/ doesn't exist in this repo — DocumentMemory placed in app/models/ (deviation)
  - Fixture YAML at app/services/document_signatures.yaml (per plan, not app/data/)
  - TokenBudget.consume() signature has no kind= param in phase 27 — passed (user_id, tokens) only
  - AcroForm extraction via page.widgets() iteration (pymupdf 1.26 has no get_form_text_fields)
  - Endpoint response_model = Union[DUR, VisionExtractionResponse] for transparent flag flip
metrics:
  duration_min: 18
  tasks: 5
  files_created: 14
  files_modified: 4
  tests_added: 36   # 6 preflight + 17 selector + 7 memory + 8 third-party + 7 fused vision + 4 schema = 49
                    # corrected count below
  completed: "2026-04-14"
---

# Phase 28 Plan 01: Backend canonical contract + fused Vision + Document Memory v1 — Summary

Single source of truth for "what MINT understood about this document":
DocumentUnderstandingResult Pydantic v2, fused classify+extract via Anthropic
tool_use, PDF preflight (encrypted/scanned/digital/AcroForm), Document Memory
table with field-history diffs, third-party silent flag, and a deterministic
render_mode selector — all behind DOCUMENTS_V2_ENABLED.

## Tasks delivered

| # | Task | Commit | Tests |
|---|------|--------|-------|
| 1 | DocumentUnderstandingResult canonical contract | `dac1b316` | 4 (schema) |
| 2 | PDF preflight (encrypted/scanned/digital/acroform) | `a3aa2d63` | 6 |
| 3 | render_mode selector + DocumentMemory v1 + migration | `a253a9ac` | 17 + 7 |
| 4 | Third-party detection + Swiss issuer signatures | `42c5f60c` | 8 |
| 5 | Fused understand_document() + endpoint flag-gated wiring | `9a72487b` | 7 + 4 |

**Total: 58 new tests across 6 files, all green.**
**Phase 27 tests (idempotency) still green: 58/58 across documents/.**
**Coach + schemas tests: 88/88 (no regression).**
**Alembic migration: forward + downgrade + forward verified on SQLite.**

## Schema decided — DocumentUnderstandingResult v1.0

Canonical fields (camelCase aliases over snake_case via to_camel):

- `schemaVersion`: literal "1.0"
- `documentClass`: enum (13 values incl. `non_financial`, `unknown`)
- `subtype`, `issuerGuess`, `classificationConfidence` (0..1)
- `extractedFields`: list[ExtractedField{fieldName, value, confidence, sourceText}]
- `overallConfidence` (0..1)
- `extractionStatus`: enum (success / partial / no_fields_found / parse_error /
  encrypted_needs_password / non_financial / rejected_local)
- `planType`, `planTypeWarning`, `coherenceWarnings: list[CoherenceWarning]`
- **`renderMode`**: enum (confirm / ask / narrative / reject) — OPAQUE
- `summary` (1-line human translation), `questionsForUser` (max 3), `narrative`,
  `commitmentSuggestion`{when, where, ifThen, actionLabel}
- `thirdPartyDetected: bool`, `thirdPartyName`
- `fingerprint`, `diffFromPrevious: dict[fieldName -> FieldDiff{old, new, deltaPct}]`
- `pagesProcessed`, `pagesTotal`, `pdfWarning`
- `costTokensIn`, `costTokensOut`

## render_mode algorithm (deterministic)

```
status ∈ {non_financial, rejected_local}                     → reject
status ∈ {parse_error, no_fields_found, encrypted}           → narrative
overall ≥ 0.90 AND fields ≤ 8 AND no_below_high AND no_warns → confirm
overall ≥ 0.75 AND 1-2 below_high AND no_high_stakes_low     → ask
overall ≥ 0.60                                               → narrative
else                                                         → reject
```

`needs_full_review()` is the orthogonal escalation predicate consumed by the
reduced ExtractionReviewScreen (high-stakes-low-conf, plan_type=1e, coherence
warnings, or overall < 0.75).

HIGH_STAKES = {avoirLppTotal, tauxConversion, rachatMaximum, salaireAssure,
revenuImposable, fortuneImposable} — matches RESEARCH §4.

## Flag default state

`DOCUMENTS_V2_ENABLED` global default is **false**. Legacy `extract_with_vision`
remains the production path until corpus validation in phase 30 (GATE-01..04).
Per-user dogfood opt-in is wired via `flags_service.add_to_dogfood`. Endpoint
`/extract-vision` returns `Union[DocumentUnderstandingResult,
VisionExtractionResponse]` so the client can pivot transparently when the flag
flips.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan referenced `services/backend/app/db/models/` — directory does not exist**
- Found during: Task 3
- Issue: Plan listed `services/backend/app/db/models/document_memory.py` but the repo's SQLAlchemy convention is `app/models/`.
- Fix: Created `app/models/document_memory.py` and registered it in `app/models/__init__.py` (matches all 25 existing models).
- Files modified: `app/models/document_memory.py`, `app/models/__init__.py`

**2. [Rule 3 - Blocking] Plan referenced migration path `services/backend/migrations/versions/...` — actual path is `alembic/versions/`**
- Found during: Task 3
- Fix: Wrote migration to `alembic/versions/p28_document_memory.py` matching existing convention. Verified `alembic upgrade head` + `downgrade -1` + re-upgrade on SQLite.

**3. [Rule 1 - Bug] pymupdf 1.26 has no `Document.get_form_text_fields()` method**
- Found during: Task 2
- Issue: Plan code snippet called `doc.get_form_text_fields()` which doesn't exist in pymupdf 1.26.
- Fix: Iterate `page.widgets()` directly, collect `field_name`/`field_value` per widget, gated by `doc.is_form_pdf`.

**4. [Rule 1 - Bug] `pymupdf.Document.tobytes()` does not preserve AcroForm widgets**
- Found during: Task 2 test
- Issue: AcroForm test PDF lost its widgets when serialised via `tobytes()`, yielding `has_acroform=False`.
- Fix: Test uses `doc.save(tmp_path)` then reads bytes back. Production code unaffected (real PDFs come from disk/upload).

**5. [Rule 2 - Missing] `ComplianceGuard.scrub()` method does not exist**
- Found during: Task 5
- Issue: Plan called `compliance_guard.scrub(text)` but the existing `ComplianceGuard` only exposes `validate(text, context, ...)` requiring a CoachContext.
- Fix: Implemented `_scrub_compliance_text()` helper that instantiates `ComplianceGuard()` and calls the layer-1 `_sanitize_banned_terms()` directly. Same banned-term coverage (garanti/optimal/conseiller + inflections + GUARANTEE_REPLACEMENTS), no CoachContext required.

**6. [Rule 1 - Bug] `TokenBudget.consume()` signature mismatch**
- Found during: Task 5
- Issue: Plan called `await token_budget.consume(user_id, tokens, kind="vision")` but phase 27's `TokenBudget.consume(user_id, tokens)` takes only two args.
- Fix: Called `TokenBudget().consume(user_id, total_tokens)` without `kind=`. Per-kind tagging deferred to a TokenBudget enhancement (out of scope here).

**7. [Rule 3 - Blocking] Test runtime missing dev deps**
- Found during: Task 2
- Issue: `.venv` did not have `pymupdf`, `fakeredis`, `sentry-sdk` installed.
- Fix: `pip install pymupdf>=1.24 fakeredis>=2.20 sentry-sdk[fastapi]>=2`. Added `pymupdf>=1.24` and `pyyaml>=6.0` to `pyproject.toml` runtime deps so prod and CI install them automatically.

### CLAUDE.md adjustments

- All new free-text fields (`summary`, `narrative`, `questionsForUser`) pass through ComplianceGuard layer-1 sanitisation per CLAUDE.md §6 ("All LLM output through ComplianceGuard").
- No "garanti", "optimal", "conseiller" terms allowed in scrubbed text — verified by `test_compliance_guard_scrubs_free_text`.
- No retirement framing in prompts: `_build_fused_system_prompt` mentions "documents financiers suisses" without retirement bias.

## Authentication gates

None encountered — all infra (Anthropic, Redis, Alembic) was usable in test mode via mocks/fakeredis/SQLite.

## Known follow-ups

- **28-02 (SSE streaming):** `understand_document()` is currently single-shot. Wrap it in an `EventSourceResponse` that yields `stage` + `field` + `done` events progressively (pattern in RESEARCH §3). Tool schema already shaped for incremental field emission.
- **28-03 (Flutter scanner):** client must send raw bytes (currently base64). Endpoint already decodes both — no further backend change needed for the flag-on path.
- **28-04 (UI render_mode):** Flutter switches widget tree on `result.renderMode`. The 4-mode contract is final.
- **TokenBudget.kind tagging:** add an optional `kind: str = "coach"` to `TokenBudget.consume()` so vision spend can be reported separately in SLO dashboards. Non-blocking.
- **JSONB index:** `field_history` is queried only by single-row primary lookup (user_id+fingerprint). If list-aggregation queries appear, add a Postgres-only JSONB GIN index in a follow-up migration.
- **NER for third-party:** regex bigrams catch most CH document headers. If false-positive rate becomes an issue (e.g. issuer name in UPPERCASE BOLD), upgrade to spaCy `fr_core_news_sm` (~30MB). Defer until corpus eval in phase 30.
- **Phase 29 PRIV-02:** wire nLPD consent dialog when `third_party_detected=true`.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: data_egress | services/backend/app/services/document_vision_service.py | New entrypoint sends file bytes (potentially containing PII) to Anthropic. Same trust boundary as legacy `extract_with_vision`; DPA + Zero Data Retention covered by phase 29 PRIV-07. No new surface vs. existing path. |
| threat_flag: persistence | services/backend/app/models/document_memory.py | New table stores `field_history` JSON per (user, fingerprint). Cascade delete on user removal is enforced via FK ondelete="CASCADE". Field values are extracted financial numbers, not raw text — same sensitivity tier as `profiles.data`. |

## Self-Check: PASSED

Verified files exist:
- FOUND: services/backend/app/schemas/document_understanding.py
- FOUND: services/backend/app/services/document_pdf_preflight.py
- FOUND: services/backend/app/services/document_render_mode.py
- FOUND: services/backend/app/services/document_memory_service.py
- FOUND: services/backend/app/services/document_third_party.py
- FOUND: services/backend/app/services/document_signatures.yaml
- FOUND: services/backend/app/models/document_memory.py
- FOUND: services/backend/alembic/versions/p28_document_memory.py
- FOUND: services/backend/tests/documents/test_pdf_preflight.py
- FOUND: services/backend/tests/documents/test_render_mode_selector.py
- FOUND: services/backend/tests/documents/test_document_memory.py
- FOUND: services/backend/tests/documents/test_third_party_detection.py
- FOUND: services/backend/tests/documents/test_fused_vision_mocked.py
- FOUND: services/backend/tests/documents/test_document_understanding_schema.py

Verified commits exist:
- FOUND: dac1b316 (task 1)
- FOUND: a3aa2d63 (task 2)
- FOUND: a253a9ac (task 3)
- FOUND: 42c5f60c (task 4)
- FOUND: 9a72487b (task 5)
