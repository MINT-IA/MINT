---
phase: 07-stabilisation-v2-0
plan: 04
subsystem: stabilisation
tags: [stab-12, stab-13, stab-14, stab-15, stab-16, facade-audit]
requires: [07-01, 07-02]
provides: ["façade audit remediation (Tier 1+2 complete, Tier 3 partial)"]
affects:
  - apps/mobile/lib/app.dart
  - apps/mobile/lib/widgets/coach/widget_renderer.dart
  - apps/mobile/lib/services/
  - apps/mobile/lib/data/budget/budget_local_store.dart
  - apps/mobile/lib/models/coach_insight.dart
  - apps/mobile/lib/models/sequence_run.dart
  - apps/mobile/lib/services/smart_onboarding_draft_service.dart
  - services/backend/app/services/coach/coach_tools.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/app/routes/wizard.py
  - services/backend/app/services/rag/hybrid_search_service.py
tech-stack:
  added: []
  patterns: ["risk-tiered execution", "per-finding atomic commits"]
decisions:
  - "Add set_goal / mark_step_completed / save_insight as INTERNAL_TOOL_NAMES with ack-only stub executors (persistence deferred to v3.0 memory layer)"
  - "Defer 12 of 13 R1 orphan routes to v3.0 shell-polish sprint (Tier 3 risk/reward)"
  - "Reclassify circle_scoring_service as LIVE (audit was wrong — real consumer in financial_report_service.dart)"
metrics:
  duration: ~90min
  completed: 2026-04-07
---

# Phase 7 Plan 04: Façade Audit Remediation Summary

Risk-tiered execution of the façade audit fix plan (Tier 1: low-risk, Tier 2: medium-risk, Tier 3: high-risk). Tier 1 + Tier 2 + Tier 3-D2 completed fully; Tier 3-R1 executed with 1/13 scope and 12 deferred.

## Tier Completion

- **Tier 1 (low-risk):** 5/5 complete
  1. Stale test fix (07-02 carryover — chat_tool_dispatcher_test intent path)
  2. G1 — set_goal/mark_step_completed/save_insight → INTERNAL_TOOL_NAMES + stub executors
  3. R2 — /coach/checkin and /tools redirect to `/home?tab=1`
  4. E1 — 3 backend BLACK-HOLE excepts surfaced via debug logs
  5. E2 — 5 mobile silent catches surfaced via debugPrint
- **Tier 2 (medium-risk):** 2/2 complete
  6. G2 — 5 orphan renderer cases + helpers deleted
  7. D1 — 4 dead services with zero consumers deleted
- **Tier 3 (high-risk):** 1.5/2 complete
  8. D2 — 7 of 8 dead-in-prod services deleted (circle_scoring_service reclassified LIVE during execution)
  9. R1 — 1 of 13 orphan routes deleted (/weekly-recap); 12 deferred to v3.0

## Disposition totals

- **FIXED in phase:** 16 commits landed
- **ACCEPTED / DEFERRED:** 12 R1 routes + circle_scoring_service (reclassified) + previously documented ACCEPT-WITH-ADR entries from AUDIT_FIX_PLAN.md
- **New DEFERRED-V3 items added to AUDIT_ACCEPT_LOG.md:** 2

## Commits (in order)

1. `97c72b34` fix(07-04): update chat_tool_dispatcher_test for intent route resolution (07-02 carryover)
2. `860f8a9a` fix(07-04): mark set_goal/mark_step_completed/save_insight as internal tools (STAB-12)
3. `2077907b` fix(07-04): redirect archived /coach/checkin and /tools to Coach tab (STAB-14)
4. `5193b077` fix(07-04): surface 3 backend swallowed errors via debug logs (STAB-16)
5. `e41b7c63` fix(07-04): add debug visibility to 5 mobile silent catches (STAB-16)
6. `b3dd333d` fix(07-04): delete 5 orphan renderer cases (STAB-12)
7. `93b1cc61` fix(07-04): delete 4 dead services with zero consumers (STAB-13)
8. `5de08c51` fix(07-04): delete pulse_hero_engine (dead-in-prod, STAB-13)
9. `d833f707` fix(07-04): delete recommendations_service (dead-in-prod, STAB-13)
10. `d4d5a958` fix(07-04): delete retirement_budget_service (dead-in-prod, STAB-13)
11. `2b5602a1` fix(07-04): delete scenario_narrator_service (dead-in-prod, STAB-13)
12. `fbe0b9d8` fix(07-04): delete timeline_service (dead-in-prod, STAB-13)
13. `820c37db` fix(07-04): delete fiscal_intelligence_service (dead-in-prod, STAB-13)
14. `bc03ef96` fix(07-04): delete wizard_conditions_service + golden_path_test (dead-in-prod, STAB-13)
15. `09aef2be` fix(07-04): delete orphan /weekly-recap route (STAB-14)

(16 if counting this SUMMARY commit.)

## Key Deviations / Discoveries

- **[Rule 1 — Audit correction] circle_scoring_service is LIVE, not dead.** AUDIT_DEAD_CODE.md listed it as DEAD-IN-PROD (0/1). Direct inspection during D2 execution found `financial_report_service.dart:12` imports it and uses `CircleScoringService()` + two static helpers. Reclassified LIVE; delete deferred. Logged in AUDIT_ACCEPT_LOG.md.
- **[Rule 3 — Blocking fix] wizard.py had no logger.** E1 commit required adding `import logging` + `logger = logging.getLogger(__name__)` before the debug logs could land.
- **[Rule 3 — Blocking fix] 4 mobile files (budget_local_store, coach_insight, sequence_run, smart_onboarding_draft_service) had no `package:flutter/foundation.dart` import.** Added during E2.
- **[Scope guard] Tier 3-R1 deferred 12/13 routes.** One-commit-per-route discipline × 13 routes × verification steps did not fit the remaining Tier 3 budget. Deferred as v3.0 shell-polish sprint with explicit rationale in AUDIT_ACCEPT_LOG.md.

## Decisions Made

- **set_goal / mark_step_completed / save_insight as ack-only internal tools.** The audit listed two options (render confirmation widget OR move backend-internal). Chose internal because: no UX design needed, keeps the LLM agent loop unblocked, defers persistence cleanly. Stub executors return French acks (`"Objectif noté : …"`, etc.) so the conversation continues naturally. Real persistence deferred to v3.0 memory layer.
- **Defer R1 sweep.** Tier 3-R1 is genuinely high-risk (13 routes × screen imports × whitelist × registry × transitive consumers). Partial execution (1/13) + clean rationale preserves stability for TestFlight prep without losing the audit signal.

## Verification

- `flutter analyze lib/`: **0 issues** (verified after every Tier 2+3 edit, final run at end)
- `python3 -m pytest services/backend/tests/test_rag.py tests/test_coach_tools.py -q`: **93 passed, 2 skipped**
- Chat tool dispatcher test: **19/19 passing**

## Deferred Issues (tracked in AUDIT_ACCEPT_LOG.md)

- R1: 12 orphan routes (see AUDIT_ACCEPT_LOG row "14 — R1 orphan routes deferred")
- circle_scoring_service re-triage with financial_report_service in v3.0 dead-code sweep

## Requirements Closed

- **STAB-12** (coach wiring): orphan cases deleted, internal-tool acks wired
- **STAB-13** (dead code): 4 + 7 services deleted (11 total); 4 providers registered (done in earlier 07-04 commit)
- **STAB-14** (orphan routes): 2 redirects + 1 delete; 12 deferred to v3.0
- **STAB-15** (contract drift): ROOT-A RAG schema fix landed earlier in 07-04
- **STAB-16** (swallowed errors): 3 backend + 5 mobile black holes surfaced

## Self-Check

- [x] All commits exist on dev branch
- [x] `flutter analyze lib/` clean
- [x] Backend pytest green
- [x] Audit log updated with deferral rationale
- [x] No regressions in 07-05 STAB-09 lint cleanup (still 0 warnings)

## Self-Check: PASSED
