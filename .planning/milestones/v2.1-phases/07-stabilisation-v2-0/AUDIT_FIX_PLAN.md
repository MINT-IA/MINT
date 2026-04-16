# AUDIT_FIX_PLAN — Disposition table for 07-01 findings (STAB-12..16)

**Generated:** 2026-04-07
**Plan:** 07-04
**Method:** Every BROKEN/MISSING/DEAD/ORPHAN/SILENT-DROP/BLACK-HOLE row from the 5 audit reports is listed with a disposition (`FIX-IN-PHASE-7` or `ACCEPT-WITH-ADR`) and an owner task. Accepted findings have rationale + v3.0 revisit pointer recorded in `AUDIT_ACCEPT_LOG.md`.

---

## Strategic sequencing (root-cause first)

Per 07-01-SUMMARY insight, two root causes collapse ~25 findings:

1. **ROOT-A — `RAGQueryRequest`/`RAGQueryResponse` missing tools/tool_calls** (`schemas/rag.py`). Fix unblocks STAB-15 E1 REQUEST-DROP + E1 PHANTOM + the backend-RAG path for all 4 coach tools.
2. **ROOT-B — 4 P0 providers consumed in prod but unregistered in `app.dart`** (`MintStateProvider`, `FinancialPlanProvider`, `CoachEntryPayloadProvider`, `OnboardingProvider`). Fix collapses ~13 `try/catch (_)` NEEDS-VERIFY hits from STAB-16.

Execute ROOT-A and ROOT-B in the first two commits, then work through remaining findings.

---

## STAB-12 — Coach wiring findings

| # | Finding | Source | Disposition | Task / commit group |
|---|---------|--------|-------------|---------------------|
| 12.1 | `route_to_screen` SILENT-DROP at renderer (intent path) | row 6 | **DONE in 07-02** | Already fixed (commit `52d8e9bc`). Mark resolved. |
| 12.2 | `set_goal` missing renderer case | row 7 | **FIX-IN-PHASE-7** | Move to `INTERNAL_TOOL_NAMES` (backend persists, no UX) — commit G1 |
| 12.3 | `mark_step_completed` missing renderer case | row 8 | **FIX-IN-PHASE-7** | Move to `INTERNAL_TOOL_NAMES` — commit G1 |
| 12.4 | `save_insight` missing renderer case | row 9 | **FIX-IN-PHASE-7** | Move to `INTERNAL_TOOL_NAMES` — commit G1 |
| 12.5 | `generate_document` missing renderer case | row 18 | **DONE in 07-02** | Already fixed. Mark resolved. |
| 12.6 | `record_check_in` BYOK missing | row 16 | **DONE in 07-02** | Already fixed. Mark resolved. |
| 12.7 | `generate_financial_plan` BYOK missing | row 17 | **DONE in 07-02** | Already fixed. Mark resolved. |
| 12.8 | Orphan renderer case `show_retirement_comparison` | cross-product | **FIX-IN-PHASE-7** | DELETE case + helper — commit G2 |
| 12.9 | Orphan renderer case `show_budget_overview` | cross-product | **FIX-IN-PHASE-7** | DELETE — commit G2 |
| 12.10 | Orphan renderer case `show_choice_comparison` | cross-product | **FIX-IN-PHASE-7** | DELETE — commit G2 |
| 12.11 | Orphan renderer case `show_pillar_breakdown` | cross-product | **FIX-IN-PHASE-7** | DELETE — commit G2 |
| 12.12 | Orphan renderer case `show_comparison_card` | cross-product | **FIX-IN-PHASE-7** | DELETE — commit G2 |
| 12.13 | `confidence` field unused in `_buildRouteSuggestion` | E1 bonus | **ACCEPT-WITH-ADR** | Requires UX design for low-confidence fallback card. Defer to v3.0 coach UX polish. |

---

## STAB-13 — Dead code findings

### Providers (Part B — all P0, ROOT-B)

| # | Provider | Disposition | Task |
|---|----------|-------------|------|
| 13.B1 | `MintStateProvider` unregistered | **FIX-IN-PHASE-7** | Register in `app.dart` — commit ROOT-B |
| 13.B2 | `FinancialPlanProvider` unregistered | **FIX-IN-PHASE-7** | Register — commit ROOT-B |
| 13.B3 | `CoachEntryPayloadProvider` unregistered | **FIX-IN-PHASE-7** | Register — commit ROOT-B |
| 13.B4 | `OnboardingProvider` unregistered | **FIX-IN-PHASE-7** | Register — commit ROOT-B |

### Part C.1 — DEAD services (0 consumers at all)

| # | File | Disposition |
|---|------|-------------|
| 13.C1a | `backend_coach_service.dart` | **FIX-IN-PHASE-7** DELETE — commit D1 |
| 13.C1b | `cap_step_title_resolver.dart` | **FIX-IN-PHASE-7** DELETE — commit D1 |
| 13.C1c | `enhanced_confidence_scorer.dart` | **FIX-IN-PHASE-7** DELETE — commit D1 |
| 13.C1d | `onboarding_analytics_helper.dart` | **FIX-IN-PHASE-7** DELETE — commit D1 |

### Part C.2 — DEAD-IN-PRODUCTION services (tests-only)

| # | File | Disposition | Notes |
|---|------|-------------|-------|
| 13.C2a | `affiliate_service.dart` | **ACCEPT-WITH-ADR** | Out-of-scope feature (v3.0 commerce); keep test coverage as spec |
| 13.C2b | `annual_refresh_service.dart` | **ACCEPT-WITH-ADR** | Vision feature v3.0 |
| 13.C2c | `check_in_amount_parser.dart` | **ACCEPT-WITH-ADR** | Candidate for STAB-04 future wiring; defer until record_check_in pipeline hardened |
| 13.C2d | `circle_scoring_service.dart` | **FIX-IN-PHASE-7** DELETE — commit D2 |
| 13.C2e | `financial_health_score_service.dart` | **ACCEPT-WITH-ADR** | Candidate FRI score source; needs PM decision before delete |
| 13.C2f | `ocr_sanitizer.dart` | **ACCEPT-WITH-ADR** | Candidate for scan pipeline hardening v3.0 |
| 13.C2g | `pulse_hero_engine.dart` | **FIX-IN-PHASE-7** DELETE — commit D2 |
| 13.C2h | `recommendations_service.dart` | **FIX-IN-PHASE-7** DELETE — commit D2 |
| 13.C2i | `retirement_budget_service.dart` | **FIX-IN-PHASE-7** DELETE — commit D2 |
| 13.C2j | `scenario_narrator_service.dart` | **FIX-IN-PHASE-7** DELETE — commit D2 |
| 13.C2k | `timeline_service.dart` | **FIX-IN-PHASE-7** DELETE — commit D2 (matches orphan route `/timeline`) |
| 13.C2l | `fiscal_intelligence_service.dart` | **FIX-IN-PHASE-7** DELETE — commit D2 |
| 13.C2m | `wizard_conditions_service.dart` | **FIX-IN-PHASE-7** DELETE — commit D2 |

### Part C.3 — ~20 ORPHAN candidates

**Disposition:** **ACCEPT-WITH-ADR** as a group. Per the plan's stretch guidance, spending ~30 min triaging 20 services at 1-2 consumers each would sacrifice quality for completeness. Documented in ACCEPT_LOG as "v3.0 dead-code sweep". Low-risk — having 1-2 consumers means they're not dead.

---

## STAB-14 — Orphan routes findings (17 confirmed + 9 verify)

### Confirmed orphans — DELETE

| # | Path | Disposition | Task |
|---|------|-------------|------|
| 14.6 | `/auth/verify` | **FIX-IN-PHASE-7** DELETE route (screen kept, wire from verify email if needed) | commit R1 |
| 14.24 | `/coach/history` | **FIX-IN-PHASE-7** DELETE route + screen file | commit R1 |
| 14.39 | `/check/debt` | **FIX-IN-PHASE-7** DELETE route | commit R1 |
| 14.63 | `/scan/avs-guide` | **FIX-IN-PHASE-7** DELETE route + redirect shim `/document-scan/avs-guide` | commit R1 |
| 14.90 | `/weekly-recap` | **FIX-IN-PHASE-7** DELETE route | commit R1 |
| 14.91 | `/cantonal-benchmark` | **FIX-IN-PHASE-7** DELETE route | commit R1 |
| 14.93 | `/about` | **FIX-IN-PHASE-7** DELETE route | commit R1 |
| 14.97 | `/timeline` | **FIX-IN-PHASE-7** DELETE route (+ screen) | commit R1 |
| 14.98 | `/confidence` | **FIX-IN-PHASE-7** DELETE route | commit R1 |
| 14.99 | `/score-reveal` | **FIX-IN-PHASE-7** DELETE route | commit R1 |
| 14.107 | `/open-banking` | **FIX-IN-PHASE-7** DELETE route | commit R1 |
| 14.108 | `/open-banking/transactions` | **FIX-IN-PHASE-7** DELETE route | commit R1 |
| 14.109 | `/open-banking/consents` | **FIX-IN-PHASE-7** DELETE route | commit R1 |

### Wire Spec V2 archived — REDIRECT

| # | Path | Disposition |
|---|------|-------------|
| 14.21 | `/coach/checkin` | **FIX-IN-PHASE-7** REDIRECT `→ /home?tab=1` — commit R2 |
| 14.95 | `/tools` | **FIX-IN-PHASE-7** REDIRECT `→ /home?tab=1` — commit R2 |

### Verify-then-decide (9) — ACCEPT

The 9 verify candidates (rows 20, 22, 40, 41, 89, 92, 94, 96, 110) have 0-1 indirect callers. **ACCEPT-WITH-ADR** as a group for v3.0 shell polish — no shipping risk because they're 404-proof (route exists, just hard to reach). Delete-spree risk > benefit.

---

## STAB-15 — Contract drift findings

| # | Finding | Disposition | Task |
|---|---------|-------------|------|
| 15.1 | E1 `RAGQueryRequest.tools` REQUEST-DROP | **FIX-IN-PHASE-7** | ROOT-A commit |
| 15.2 | E1 `RAGQueryResponse.tool_calls` PHANTOM | **FIX-IN-PHASE-7** | ROOT-A commit |
| 15.3 | E1 `route_to_screen.intent/confidence` SILENT-DROP | **DONE in 07-02** (intent path); confidence gate **ACCEPT-WITH-ADR** (UX decision) |
| 15.4 | E4 `/api/v1/coach/chat` DEAD on mobile | **ACCEPT-WITH-ADR** | Architectural decision: keep endpoint as future migration target. Recorded in ACCEPT_LOG. |
| 15.5 | E6 `DocumentUploadResponse.warnings` NEEDS-VERIFY | **ACCEPT-WITH-ADR** | Needs 5-min inline parser diff; defer to v3.0 document polish |
| 15.6 | E6 `fields_total` / `raw_text_preview` / `rag_indexed` | **ACCEPT-WITH-ADR** | Same as 15.5 |

---

## STAB-16 — Swallowed errors findings

### Confirmed BLACK-HOLEs (9)

| # | Location | Disposition |
|---|----------|-------------|
| 16.A4 | `routes/wizard.py:385,422` — silent `except Exception: pass` | **FIX-IN-PHASE-7** — add explanatory comment or rethrow — commit E1 |
| 16.A9 | `services/rag/hybrid_search_service.py:309` — `# pragma: no cover` | **FIX-IN-PHASE-7** — add explanatory comment — commit E1 |
| 16.A12 | `api/v1/endpoints/coach_chat.py:1265` — parse swallow | **FIX-IN-PHASE-7** — add comment documenting best-effort — commit E1 |
| 16.B11 | `widgets/coach/widget_renderer.dart:125,500-502` — silent provider-absent catches | **FIX-IN-PHASE-7** — cleanup now that ROOT-B registers providers — commit E2 |
| 16.B17 | `data/budget/budget_local_store.dart:62` — silent return null | **FIX-IN-PHASE-7** — add debugPrint — commit E2 |
| 16.B19 | `models/coach_insight.dart:129` — silent return [] | **FIX-IN-PHASE-7** — add debugPrint — commit E2 |
| 16.B20 | `models/sequence_run.dart:298` — silent return null | **FIX-IN-PHASE-7** — add debugPrint — commit E2 |
| 16.B21 | `services/smart_onboarding_draft_service.dart:34` — silent return {} | **FIX-IN-PHASE-7** — add debugPrint — commit E2 |

### NEEDS-VERIFY (~65)

**Disposition:** **ACCEPT-WITH-ADR** as a group. Per plan's hard constraint "don't go down a rabbit hole — Phase 7 is stabilization, not a try/except crusade." The 9 confirmed BLACK-HOLEs are fixed; the remaining ~65 are categorized NEEDS-VERIFY precisely because mechanical grep couldn't classify them without a line-by-line read. Defer to v3.0 error-path audit (one week dedicated sprint).

---

## Commit groups (execution order)

1. **ROOT-A** — `fix(backend): thread tools/tool_calls through /rag/query (STAB-15)` — `schemas/rag.py` + `rag.py` endpoint
2. **ROOT-B** — `fix(mobile): register 4 missing providers in MultiProvider (STAB-13)` — `app.dart`
3. **G1** — `fix(coach): move set_goal/mark_step_completed/save_insight to INTERNAL_TOOL_NAMES (STAB-12)` — `coach_tools.py`
4. **G2** — `fix(coach): delete 5 orphan renderer cases (STAB-12)` — `widget_renderer.dart`
5. **D1** — `chore: delete 4 dead services with zero consumers (STAB-13)` — `services/*.dart`
6. **D2** — `chore: delete 8 dead-in-prod services (STAB-13)` — `services/*.dart`
7. **R1** — `chore: delete 13 confirmed orphan routes (STAB-14)` — `app.dart`
8. **R2** — `fix: redirect 2 archived coach routes to /home (STAB-14)` — `app.dart`
9. **E1** — `fix(backend): document 3 black-hole excepts (STAB-16)` — `wizard.py`, `hybrid_search_service.py`, `coach_chat.py`
10. **E2** — `fix(mobile): surface 5 silent catches via debugPrint (STAB-16)` — `widget_renderer.dart`, `budget_local_store.dart`, `coach_insight.dart`, `sequence_run.dart`, `smart_onboarding_draft_service.dart`

Each group is atomic. Verify after each: `flutter analyze` (for mobile groups) / `pytest` (for backend groups).

---

## Accept log

Full rationale for every `ACCEPT-WITH-ADR` row lives in `AUDIT_ACCEPT_LOG.md` (sibling file). Each entry: finding ID + why-cant-fix-in-v2.1 + where-to-revisit (v3.0 todo / ADR path).
