# AUDIT_ACCEPT_LOG — Rationale for findings deferred past v2.1

**Generated:** 2026-04-07
**Plan:** 07-04
**Purpose:** Every `ACCEPT-WITH-ADR` row from `AUDIT_FIX_PLAN.md` has an explicit rationale here: why it can't/shouldn't be fixed in v2.1 stabilization, and where it should be revisited.

---

## 12.13 — `confidence` field unused in `_buildRouteSuggestion`

- **Why not fix now:** Requires UX decision. Using `confidence < threshold` to fall back to a clarifying-question card needs a designed widget (copy, layout, threshold). Outside Phase 7 "surgical wiring" scope.
- **Revisit:** v3.0 coach UX polish sprint. GSD todo: "Design and implement low-confidence fallback for route_to_screen tool." ADR placeholder: `decisions/ADR-vXXX-route-confidence-gate.md`.

---

## 13.C2a — `affiliate_service.dart` (DEAD-IN-PROD)

- **Why not fix now:** Keeping the service + tests as a spec for the unshipped affiliate feature is cheaper than re-deriving the contract later. Tests assert compliance rules that would be lost on delete.
- **Revisit:** v3.0 commerce milestone. GSD todo: "Wire affiliate_service into actions surface or delete with feature decision."

## 13.C2b — `annual_refresh_service.dart`

- **Why not fix now:** Documented vision feature (Phase 2 "Weekly Recap" / annual rhythms). Tests encode the legal cycle logic.
- **Revisit:** Phase 2 (sprint S57-S62 roadmap).

## 13.C2c — `check_in_amount_parser.dart`

- **Why not fix now:** Candidate for STAB-04 `record_check_in` hardening. Inlining the parse logic now would duplicate tested code. Safer to leave as a future wiring target.
- **Revisit:** Phase 7+ coach check-in polish. GSD todo: "Wire check_in_amount_parser into record_check_in handler."

## 13.C2e — `financial_health_score_service.dart`

- **Why not fix now:** Possible FRI (Financial Readiness Index) source. Deleting without PM confirmation risks losing the Phase 1 Financial Health Score spec. Out of stabilization scope.
- **Revisit:** Phase 1 roadmap (S51-S56). GSD todo: "Confirm FHS source-of-truth and wire or delete."

## 13.C2f — `ocr_sanitizer.dart`

- **Why not fix now:** Document scan pipeline uses a different sanitization path today; wiring this in would be a refactor, not a fix.
- **Revisit:** v3.0 document intelligence hardening.

## 13.C3 group (~20 ORPHAN candidates, 1-2 consumers each)

- **Why not fix now:** Per plan hard constraint, spending 30+ min triaging 20 borderline services sacrifices quality for completeness. Having 1-2 consumers means they're not dead. The risk of a wrong delete (breaking a real but indirect code path) outweighs the benefit.
- **Revisit:** v3.0 dead-code sweep (dedicated one-day audit). GSD todo: "Per-service triage of 20 orphan-candidate services."

---

## 14 — 9 verify-then-decide routes

- **Why not fix now:** Each needs a 2-minute caller-trace that adds up to ~20 min for zero shipping benefit (the routes compile and 404-proof). Delete-now risk > benefit.
- **Revisit:** v3.0 shell polish sprint. GSD todo: "Verify + delete/wire 9 borderline routes."

---

## 15.3 bonus — `confidence` gate on route_to_screen

- See 12.13 above (same finding, different audit).

## 15.4 — `/api/v1/coach/chat` DEAD on mobile

- **Why not fix now:** This is an architectural decision, not a wiring fix. Two options:
  1. Delete the backend endpoint (loses the cleaner `CoachChatResponse` schema that already has `tool_calls`).
  2. Migrate mobile to call `/api/v1/coach/chat` instead of `/rag/query` (bigger refactor that would obsolete the ROOT-A fix).
  Keeping both for now preserves optionality. ROOT-A makes `/rag/query` functional today; `/api/v1/coach/chat` remains a future migration target.
- **Revisit:** Phase 2+ architecture cleanup. ADR placeholder: `decisions/ADR-vXXX-coach-transport-consolidation.md`.

## 15.5 / 15.6 — `DocumentUploadResponse.warnings/fields_total/raw_text_preview/rag_indexed`

- **Why not fix now:** The mobile parser is inline in `document_service.dart`; a per-field diff is a 5-min task per field. Symptoms are not user-visible today (`warnings` is cosmetic; `fields_total` is covered by `fields_found`; `raw_text_preview` is debug).
- **Revisit:** v3.0 document polish. GSD todo: "Diff `DocumentUploadResponse` fields against inline parser."

---

## 16 NEEDS-VERIFY group (~65 try/catch sites)

- **Why not fix now:** Plan hard constraint says "don't go down a rabbit hole — Phase 7 is stabilization, not a try/except crusade." Each site needs a 5-min READ. ~65 sites × 5 min = ~5 hours with low expected hit rate (the mechanical grep already caught the high-signal BLACK-HOLE shapes). After ROOT-B + E1/E2 commits, the 9 confirmed black holes are fixed and the highest-risk provider-absent catches collapse.
- **Revisit:** v3.0 error-path audit (dedicated one-week sprint). Follow `feedback_audit_read_error_paths.md` discipline per site. GSD todo: "Full read of 65 NEEDS-VERIFY try/catch sites from AUDIT_SWALLOWED_ERRORS.md."

---

## 13.C2d circle_scoring_service — reclassified LIVE

- **Why not delete:** Audit listed as 0/1 (dead-in-prod) but direct inspection during 07-04 execution found `apps/mobile/lib/services/financial_report_service.dart:12` imports it AND uses `CircleScoringService()` + `CircleScoringService.calculateAvsGapsFromAnswers()` + `.calculateSpouseAvsGapsFromAnswers()`. The audit's grep missed this because financial_report_service was itself ORPHAN-candidate and the pattern match was repo-wide but not transitively traced.
- **Action:** Kept as LIVE. Audit row downgraded to ACCEPTED (reclassified).

## 13.C2 circle_scoring_service note
- Also note: circle_scoring_service will eventually be dead IF financial_report_service is later confirmed unused. Re-audit together in v3.0 dead-code sweep.

---

## 14 — R1 orphan routes deferred (12 of 13)

- **Why not delete now:** Each of the 13 orphan routes requires per-route verification (screen imports, tool_call_parser.validRoutes whitelist, screen_registry.dart intent map, transitive consumers) and one atomic commit + `flutter analyze lib/` per route. At ~4 tool calls × 13 routes = 52 steps, the risk/reward ratio in the final Tier 3 slot did not justify the chance of a late-session regression breaking TestFlight prep. 07-04 executed `/weekly-recap` (the single zero-risk simple-redirect case) and deferred the other 12 to a dedicated v3.0 shell-polish sprint.
- **Routes deferred:** `/auth/verify`, `/coach/history`, `/check/debt`, `/scan/avs-guide`, `/cantonal-benchmark`, `/about`, `/timeline`, `/confidence`, `/score-reveal`, `/open-banking`, `/open-banking/transactions`, `/open-banking/consents`.
- **Revisit:** v3.0 shell polish sprint. GSD todo: "Per-route delete sweep for 12 R1 deferred routes." ADR placeholder: `decisions/ADR-vXXX-orphan-route-sweep.md`.

---

## Revisit summary

| Finding | Target milestone | Owner |
|---------|------------------|-------|
| 12.13 / 15.3 confidence gate | v3.0 coach UX polish | TBD |
| 13.C2a affiliate | v3.0 commerce | TBD |
| 13.C2b annual refresh | Phase 2 (S57-S62) | TBD |
| 13.C2c check_in_amount_parser | Phase 7+ check-in polish | TBD |
| 13.C2e FHS | Phase 1 (S51-S56) | TBD |
| 13.C2f ocr_sanitizer | v3.0 doc intelligence | TBD |
| 13.C3 orphan candidates sweep | v3.0 dead-code sweep | TBD |
| 14 verify routes | v3.0 shell polish | TBD |
| 15.4 coach transport | Phase 2+ | TBD |
| 15.5/15.6 document fields | v3.0 doc polish | TBD |
| 16 NEEDS-VERIFY sweep | v3.0 error-path audit | TBD |
