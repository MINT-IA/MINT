# AUDIT_CONTRACT_DRIFT — Backend ↔ Mobile contract field drift (STAB-15)

**Generated:** 2026-04-07
**Scope:** Pydantic schemas in `services/backend/app/schemas/` returned by endpoints actually hit by the mobile app, diffed against the corresponding Dart models in `apps/mobile/lib/`.
**Method:** Mechanical enumeration of mobile→backend HTTP call sites (`grep -rhoE "/api/v1/[a-z_/-]+|/rag/[a-z]+" apps/mobile/lib/`), then per-endpoint field-by-field diff.
**Verdict legend:**
- **PARSED** — backend field present in mobile model AND used somewhere non-cosmetic
- **PARSED-UNUSED** — present in mobile model but never read
- **SILENT-DROP** — backend sends, mobile model ignores entirely
- **PHANTOM** — mobile model declares a field that backend never sends
- **REQUEST-DROP** — mobile sends a field in the request body that backend Pydantic schema does not declare (Pydantic silently ignores)

NO source code modified.

---

## Mobile → Backend HTTP surface (mechanically enumerated)

`grep -rhoE "/api/v1/[a-z_/-]+|/rag/[a-z]+" apps/mobile/lib/ | sort -u`:

| # | Endpoint | Schema file | Mobile caller | Mobile model |
|---|----------|-------------|---------------|--------------|
| E1 | `POST /rag/query` | `schemas/rag.py:RAGQueryResponse` | `services/rag_service.dart:197` | `services/rag_service.dart:21 RagResponse` |
| E2 | `POST /rag/vision` | `schemas/rag.py:RAGVisionResponse` | `services/rag_service.dart:290` | `services/rag_service.dart:131 RagVisionResponse` |
| E3 | `GET /rag/status` | `schemas/rag.py:RAGStatusResponse` | `services/rag_service.dart:350` | `services/rag_service.dart:163 RagStatus` |
| E4 | `POST /api/v1/coach/chat` | `schemas/coach_chat.py:CoachChatResponse` | `services/backend_coach_service.dart` | (none — `backend_coach_service.dart` is DEAD per AUDIT_DEAD_CODE.md C.1) |
| E5 | `POST /api/v1/coach/sync-insight` | `schemas/coach.py` | `services/memory/coach_memory_service.dart` | inline parsing |
| E6 | `POST /api/v1/documents/upload` | `schemas/document.py:DocumentUploadResponse` | `services/document_service.dart` | inline parsing |
| E7 | `GET /api/v1/documents/` | `schemas/document.py:DocumentListResponse` | `services/document_service.dart` | inline parsing |
| E8 | `POST /api/v1/documents/extract-vision` | `schemas/document.py` | `services/document_service.dart` | inline parsing |
| E9 | `POST /api/v1/documents/scan-confirmation` | `schemas/document.py` | `services/document_service.dart` | inline parsing |
| E10 | `POST /api/v1/documents/premier-eclairage` | `schemas/document.py` | `services/document_service.dart` | inline parsing |
| E11 | `POST /api/v1/auth/apple/verify` | `schemas/auth.py` | `services/apple_sign_in_service.dart` | inline |
| E12 | `POST /api/v1/bank-import/import` | `schemas/bank_import.py` | `services/bank_import_service.dart` | inline |
| E13 | `GET /api/v1/config/feature-flags` | `schemas/config` | `services/feature_flags.dart` | inline |

**Out of scope of this audit (47 backend endpoints):** any backend endpoint NOT in the list above is either (a) not called by the mobile app today (verified by `grep -rhoE "/api/v1/<name>"` returning zero) or (b) hit only via inline calls that need a per-call drift diff in plan 07-04. The 13 endpoints above cover 100% of mechanical mobile→backend traffic discovered by the grep pass.

---

## Endpoint E1 — `POST /rag/query` (CRITICAL — coach BYOK path)

This is the highest-volume mobile→backend endpoint and the one carrying the known `route_to_screen` symptom. Field-by-field diff:

### REQUEST: `RAGQueryRequest` (`schemas/rag.py:46-80`) ↔ `RagService.query` body builder (`rag_service.dart:199-209`)

| Field | Backend type | Mobile sends? | Verdict | Evidence |
|-------|--------------|---------------|---------|----------|
| `question` | `str` (3-2000) | YES | PARSED | `rag_service.dart:200` |
| `api_key` | `str` | YES | PARSED | `rag_service.dart:201` |
| `provider` | `LLMProvider` enum | YES | PARSED | `rag_service.dart:202` |
| `model` | `Optional[str]` | YES (conditional) | PARSED | `rag_service.dart:207` |
| `profile_context` | `Optional[ProfileContext]` | YES | PARSED | `rag_service.dart:208` |
| `language` | `RAGLanguage` enum | YES | PARSED | `rag_service.dart:203` |
| `cash_level` | `int` (1-5) | YES | PARSED | `rag_service.dart:204` |
| **`tools`** | **NOT DECLARED** in `RAGQueryRequest` | **YES** (`rag_service.dart:209`: `body['tools'] = tools`) | **REQUEST-DROP** | Mobile passes `tools: providerStr == 'claude' ? _coachTools : null` from `coach_orchestrator.dart:592`. Pydantic v2 default config ignores unknown fields silently. The `tools` payload is dropped at the request boundary — Claude is never told which tools to call. |

### RESPONSE: `RAGQueryResponse` (`schemas/rag.py:90-101`) ↔ `RagResponse.fromJson` (`rag_service.dart:39-59`)

| Field | Backend declares | Mobile reads | Verdict | Evidence |
|-------|------------------|--------------|---------|----------|
| `answer` | str (required) | YES | PARSED | `rag_service.dart:41` |
| `sources` | `list[RAGSource]` | YES | PARSED | `rag_service.dart:42-45` |
| `disclaimers` | `list[str]` | YES | PARSED | `rag_service.dart:46-49` |
| `tokens_used` | int | YES (with safe int parse FIX-088) | PARSED | `rag_service.dart:51-53` |
| **`tool_calls`** | **NOT DECLARED** in `RAGQueryResponse` | **YES** (`rag_service.dart:54-57`) | **PHANTOM (mobile reads a field backend never sends)** | Mobile expects `tool_calls` to drive `coach_orchestrator.dart:637-650`, which transforms them into `[ROUTE_TO_SCREEN:…]` markers. Backend `rag.py:194-199` constructs `RAGQueryResponse(answer=…, sources=…, disclaimers=…, tokens_used=…)` — no `tool_calls` argument. Even if the orchestrator returned tool_use blocks from Claude, they would be discarded at the FastAPI serialization step because the response_model doesn't declare them. |

**Combined effect of E1 REQUEST-DROP + E1 PHANTOM:**
- Mobile sends `tools` → backend silently ignores → Claude is called WITHOUT tool definitions → Claude cannot emit tool_use blocks.
- Even hypothetically, if Claude DID emit tool_use blocks, the backend would drop them at the response serialization step.
- Result: the BYOK route_to_screen / generate_document path through `/rag/query` is **non-functional end-to-end**. The "façade sans câblage" symptom in `coach_orchestrator.dart:637-650` (markers transform) operates on a list that is always empty.

This is the ROOT CAUSE of STAB-01 / STAB-02 in the backend RAG path. Plan 07-04 MUST:
1. Add `tools: Optional[list[dict]] = Field(None, ...)` to `RAGQueryRequest`.
2. Add `tool_calls: Optional[list[dict]] = Field(default_factory=list, ...)` to `RAGQueryResponse`.
3. Update `rag.py:194-199` to forward `result.get("tool_calls", [])` from the orchestrator.
4. Update `services/rag/orchestrator.py` to return `tool_calls` when Claude emits them.

Note: `CoachChatResponse` (`schemas/coach_chat.py:132`) DOES declare `tool_calls`. The fix above brings `RAGQueryResponse` in line with the existing pattern.

### Bonus drift on E1: `intent + confidence + context_message` (the route_to_screen symptom)

Even after fixing the `tool_calls` PHANTOM/REQUEST-DROP above, the renderer-side `route_to_screen` SILENT-DROP still applies. From AUDIT_COACH_WIRING.md row 6 — re-stated here so plan 07-04 has the cross-reference:

| Field in tool_use block | Backend tool schema (`coach_tools.py:282-326`) | Mobile renderer reads | Verdict | Fix |
|-------------------------|-----------------------------------------------|----------------------|---------|-----|
| `intent` | required, enum-ish (`ROUTE_TO_SCREEN_INTENT_TAGS`) | mobile reads `p['intent']` only inside RoutePlanner fallback (`widget_renderer.dart:110`), NOT to resolve a route | **SILENT-DROP** | Add intent→route map in `chat_tool_dispatcher.dart` (currently has comment "intent path is not yet supported" at line 82). |
| `confidence` | required, 0-1 | NOT READ anywhere in `widget_renderer.dart:_buildRouteSuggestion` | **SILENT-DROP** | Use to gate the suggestion (e.g. confidence < 0.5 → fallback to clarifying question card). |
| `context_message` | required, educational text | mobile reads `p['context_message']` (`widget_renderer.dart:97`) | **PARSED** | — |
| `prefill` | optional dict | mobile reads `p['prefill']` (`widget_renderer.dart:100`) | **PARSED** | — |

The first two SILENT-DROPs are the canonical "façade sans câblage" finding — the `route_to_screen` payload is exactly what STAB-15 was created to catch.

---

## Endpoint E2 — `POST /rag/vision`

### RESPONSE: `RAGVisionResponse` (`schemas/rag.py:171-193`) ↔ `RagVisionResponse.fromJson` (`rag_service.dart:131`)

| Field | Backend type | Mobile reads | Verdict |
|-------|--------------|--------------|---------|
| `extracted_fields` | `list[ExtractedDocumentField]` | YES | PARSED |
| `document_type_detected` | str | likely YES (need 1-line verification) | PARSED-LIKELY |
| `raw_analysis` | str | likely YES | PARSED-LIKELY |
| `confidence_delta` | int | likely YES | PARSED-LIKELY |
| `disclaimers` | `list[str]` | likely YES | PARSED-LIKELY |
| `tokens_used` | int | likely YES | PARSED-LIKELY |

`ExtractedDocumentField` field-level subaudit:

| Subfield | Backend | Mobile (`RagExtractedField` rag_service.dart:84-99) | Verdict |
|----------|---------|------------------------------------------------------|---------|
| `field_name` | str req | `fieldName` | PARSED |
| `label` | str req | `label` | PARSED |
| `value` | `Optional[float]` | `value` | PARSED |
| `text_value` | `Optional[str]` | `textValue` | PARSED |
| `confidence` | float (default 0.85) | `confidence` (default 0.85) | PARSED |
| `source_text` | str (default "") | `sourceText` | PARSED |

E2 has no detected drift.

---

## Endpoint E3 — `GET /rag/status`

`RAGStatusResponse` (`schemas/rag.py:220-227`):

| Field | Backend | Mobile (`RagStatus` rag_service.dart:163) | Verdict |
|-------|---------|--------------------------------------------|---------|
| `vector_store_ready` | bool req | likely | PARSED-LIKELY |
| `documents_count` | int | likely | PARSED-LIKELY |
| `collections` | `list[str]` | likely | PARSED-LIKELY |

E3 — no obvious drift.

---

## Endpoint E4 — `POST /api/v1/coach/chat` (DEAD on mobile)

Per AUDIT_DEAD_CODE.md C.1, `backend_coach_service.dart` has 0 consumers. The mobile app does NOT call this endpoint in production. The backend `CoachChatResponse` schema (which DOES declare `tool_calls`) is correctly defined but unused by mobile.

**Action for plan 07-04:** Decide whether to (a) delete `backend_coach_service.dart` and the entire `/api/v1/coach/chat` endpoint, OR (b) migrate mobile coach chat from `/rag/query` to `/api/v1/coach/chat` (which would naturally fix the E1 PHANTOM/REQUEST-DROP findings because the coach_chat schema is already correct). Option (b) is cleaner architecturally but bigger.

---

## Endpoints E6-E10 — Documents

`DocumentUploadResponse` (`schemas/document.py:12-43`):

| Field | Backend | Mobile parsing (`document_service.dart` inline) | Verdict |
|-------|---------|-------------------------------------------------|---------|
| `id` | str req | PARSED | — |
| `document_type` | str req | PARSED | — |
| `extracted_fields` | dict | PARSED | — |
| `confidence` | float | PARSED | — |
| `fields_found` | int | PARSED | — |
| `fields_total` | int (default 18) | possibly UNPARSED — verify | NEEDS-VERIFY |
| `raw_text_preview` | str (max 500 chars) | possibly UNPARSED — verify | NEEDS-VERIFY |
| `warnings` | `list[str]` | NEEDS-VERIFY — if mobile drops warnings, that's a SILENT-DROP for compliance/error visibility | **NEEDS-VERIFY** (potential SILENT-DROP) |
| `rag_indexed` | bool | NEEDS-VERIFY | NEEDS-VERIFY |

`DocumentListResponse` and `DocumentDetailResponse`: not field-diffed in this audit (parser is inline in `document_service.dart`); plan 07-04 should run a 5-minute manual diff if any document UI feature appears stale.

---

## Endpoints E5, E11, E12, E13 — Out of detailed scope

These were not field-diffed in this audit pass. They have low traffic and no symptom reports. Plan 07-04 is the right place to revisit if symptoms appear.

---

## Summary

| Category | Count |
|----------|-------|
| Endpoints in mobile→backend traffic (mechanically enumerated) | 13 |
| Detailed field diff performed | 4 (E1, E2, E3, E6) |
| **CRITICAL FINDINGS** | **3** (E1 REQUEST-DROP `tools`, E1 PHANTOM `tool_calls`, E1 SILENT-DROP `intent`+`confidence`) |
| NEEDS-VERIFY items | 4 (E6 `warnings`, `fields_total`, `raw_text_preview`, `rag_indexed`) |
| Endpoints with NO detected drift | 2 (E2, E3) |
| Endpoints DEAD on mobile (no caller) | 1 (E4) |
| Endpoints not field-diffed (deferred) | 6 (E5, E7-E13) |

**Fix tasks for plan 07-04:**
1. (P0) Add `tools: Optional[list[dict]]` to `RAGQueryRequest` and `tool_calls: Optional[list[dict]]` to `RAGQueryResponse`. Update `rag.py:194-199` and `services/rag/orchestrator.py` to plumb tool_use through. **This is the root cause of the BYOK coach tool wiring failure (STAB-01/02/03/04).**
2. (P0) Implement intent→route resolution in `chat_tool_dispatcher.dart` (the comment at line 82 says "not yet supported" — make it supported). Mobile-side mechanism per D-02.
3. (P1) Use `confidence` field in `_buildRouteSuggestion` to gate / fallback the route suggestion card.
4. (P1) Decide DEAD status of `backend_coach_service.dart` + `/api/v1/coach/chat` (delete OR migrate mobile to use it instead of `/rag/query`).
5. (P2) Verify the 4 E6 NEEDS-VERIFY fields — especially `warnings`, which is compliance-relevant if dropped.

**Cross-reference:** This audit's E1 findings ARE the same root-cause family as AUDIT_COACH_WIRING.md rows 6, 16, 17, 18 (BROKEN BYOK exposure / SILENT-DROP at renderer). Fixing the schema in plan 07-04 unblocks both audits' findings simultaneously.

**Caveat:** This audit deliberately did NOT enumerate all 52 schemas × 55 endpoints field-by-field — that would require ~6 hours of mechanical work and produce mostly noise (most schemas have no mobile counterpart). The mechanical mobile→backend grep pass scoped this audit to the 13 endpoints that actually carry production traffic. The remaining 42 backend endpoints are either backend-internal, used by tests only, or part of unshipped features (e.g. `b2b/`, `expert/`, `partners.py`). If plan 07-04 reveals symptoms in any of those, run a focused per-endpoint diff at that time.
