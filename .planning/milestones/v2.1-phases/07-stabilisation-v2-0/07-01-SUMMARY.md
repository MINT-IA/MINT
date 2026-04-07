---
phase: 07-stabilisation-v2-0
plan: 01
subsystem: audit
tags: [audit, facade-sans-cablage, stab-12, stab-13, stab-14, stab-15, stab-16]
dependency_graph:
  requires: []
  provides:
    - "AUDIT_COACH_WIRING.md (STAB-12)"
    - "AUDIT_DEAD_CODE.md (STAB-13)"
    - "AUDIT_ORPHAN_ROUTES.md (STAB-14)"
    - "AUDIT_CONTRACT_DRIFT.md (STAB-15)"
    - "AUDIT_SWALLOWED_ERRORS.md (STAB-16)"
  affects:
    - "07-04-PLAN.md (audit fix sweep — every BROKEN/MISSING/DEAD/ORPHAN/SILENT-DROP/BLACK-HOLE row becomes a fix task)"
tech_stack:
  added: []
  patterns:
    - "Mechanical grep-driven audit (no manual interpretation)"
    - "5-stage end-to-end trace per coach tool"
    - "Cross-product orphan check (renderer ↔ backend)"
key_files:
  created:
    - .planning/phases/07-stabilisation-v2-0/AUDIT_COACH_WIRING.md
    - .planning/phases/07-stabilisation-v2-0/AUDIT_DEAD_CODE.md
    - .planning/phases/07-stabilisation-v2-0/AUDIT_ORPHAN_ROUTES.md
    - .planning/phases/07-stabilisation-v2-0/AUDIT_CONTRACT_DRIFT.md
    - .planning/phases/07-stabilisation-v2-0/AUDIT_SWALLOWED_ERRORS.md
  modified: []
decisions:
  - "Scoped STAB-15 to the 13 endpoints actually hit by mobile (mechanically grep-enumerated) instead of all 52 backend schemas"
  - "Categorized STAB-16 by high-signal grep patterns instead of reading all 622 try blocks"
  - "Verified no source code modified (git diff apps/ services/ empty)"
metrics:
  duration: ~80min
  completed: 2026-04-07
  tasks: 5
  files_created: 5
  source_files_modified: 0
---

# Phase 7 Plan 01: Façade-sans-câblage audit Summary

**One-liner:** Five mechanical audits exposed the root cause of MINT's BYOK coach tool failure (RAGQueryRequest/Response missing tools/tool_calls fields) plus 4 P0 providers consumed in production but registered only in tests, 17 orphan GoRouter routes, and 9 confirmed try/except black holes — all without modifying a single source file.

## What Was Built

5 audit reports under `.planning/phases/07-stabilisation-v2-0/`:

1. **AUDIT_COACH_WIRING.md (STAB-12)** — 5-stage trace of every coach tool. 4 PASS / 7 BROKEN / 5 orphan renderer cases across 18 backend tools.
2. **AUDIT_DEAD_CODE.md (STAB-13)** — 14 LIVE providers in `app.dart`, **4 P0 providers consumed but unregistered in production**, 4 dead services + 13 dead-in-production services + ~20 orphan candidates.
3. **AUDIT_ORPHAN_ROUTES.md (STAB-14)** — ~100 GoRouter paths enumerated, 17 ORPHAN findings, 9 verify-candidates, 29 redirect shims kept.
4. **AUDIT_CONTRACT_DRIFT.md (STAB-15)** — 13 mobile→backend endpoints field-diffed (4 in detail). **Root cause finding**: `RAGQueryRequest` missing `tools` field + `RAGQueryResponse` missing `tool_calls` field → BYOK coach tool path is non-functional end-to-end.
5. **AUDIT_SWALLOWED_ERRORS.md (STAB-16)** — 622 try blocks scanned, **9 confirmed BLACK-HOLE findings**, ~65 NEEDS-VERIFY, the rest BEST-EFFORT-OK by pattern.

## Findings Index (drives plan 07-04)

| Audit | PASS | BROKEN/FINDING | ORPHAN | NEEDS-VERIFY |
|-------|------|----------------|--------|--------------|
| STAB-12 (coach wiring) | 4 user-visible + 7 internal | 7 | 5 (renderer cases) | 0 |
| STAB-13 (dead code) | 14 LIVE providers | 4 P0 unregistered providers + 4 dead + 13 dead-in-prod services | ~20 | ~30 |
| STAB-14 (routes) | 80 reachable | 17 orphan | — | 9 |
| STAB-15 (contracts) | 4 endpoints clean | 3 critical (E1 REQUEST-DROP, E1 PHANTOM, E1 SILENT-DROP) | — | 4 |
| STAB-16 (errors) | ~195 OK | 9 BLACK-HOLE | — | ~65 |

## Critical Findings (P0 — must fix in plan 07-04)

1. **`RAGQueryRequest`/`RAGQueryResponse` missing tool fields** (`schemas/rag.py`) — root cause of STAB-01..04 BYOK failure. Mobile sends `tools` in request body, Pydantic silently drops it. Mobile parses `tool_calls` from response, backend never sets it. Net effect: BYOK coach tools (route_to_screen, generate_document, generate_financial_plan, record_check_in) cannot reach the user via the `/rag/query` path that actually carries production traffic.
2. **4 providers consumed in production but never registered in `app.dart` MultiProvider:** `MintStateProvider`, `FinancialPlanProvider`, `CoachEntryPayloadProvider`, `OnboardingProvider`. Production screens call `context.watch`/`context.read` on them — only saved from `ProviderNotFoundException` by silent `try/catch (_)` blocks scattered across 13 screens.
3. **Renderer SILENT-DROP at `widget_renderer.dart:_buildRouteSuggestion`** — reads `p['route']` which is never present (orchestrator emits `intent`+`confidence`+`context_message`), so `isValidRoute('')` is false → `SizedBox.shrink()`. The text marker reaches the renderer; the renderer drops it.

## Cross-cutting Insight

The four audits triangulate the SAME root cause from different angles:

- STAB-12 sees it as "7 BROKEN coach tool stages"
- STAB-13 sees it as "13 try/catch (_) blocks masking provider absence"
- STAB-15 sees it as "request/response schema fields missing"
- STAB-16 sees it as "BLACK-HOLE catches in widget_renderer + screens"

**Fixing the schemas (STAB-15) + registering the 4 providers (STAB-13) collapses ~25 of the 35+ findings.** That should be the first task in plan 07-04.

## Deviations from Plan

### Auto-fixed Issues

None — this plan explicitly forbids source code modification. All findings are reported, none fixed.

### Scoping Decisions

1. **STAB-15** scoped to 13 mobile→backend endpoints (mechanically grep-enumerated) instead of all 52 backend schemas. The 39 unaudited schemas have no mobile call site detected by grep.
2. **STAB-16** categorized by grep patterns (`pass`, `return null`, empty catch) instead of reading all 622 try blocks. Documented in audit caveat.
3. **STAB-13** Part C (services) audited at file level via import counts instead of class-by-class. Subdirectory services (`services/coach/`, `services/financial_core/`, etc.) summarized as LIVE-by-construction.

These scoping decisions are documented at the end of each audit report. They are not fixes — they are honest scope boundaries.

## Authentication Gates

None — fully automated.

## Commits

- `b8a88035` — audit(07-01): coach wiring 5-stage trace report (STAB-12)
- `e6fd0631` — audit(07-01): provider/service dead code report (STAB-13)
- `5bbd1287` — audit(07-01): GoRouter orphan routes report (STAB-14)
- `3cd807aa` — audit(07-01): backend/mobile contract drift report (STAB-15)
- `dad71019` — audit(07-01): try/except black-hole report (STAB-16)

## Verification

- [x] All 5 audit files exist at `.planning/phases/07-stabilisation-v2-0/AUDIT_*.md`
- [x] Each report contains a markdown table with explicit verdicts
- [x] Each BROKEN/MISSING/DEAD/ORPHAN/SILENT-DROP/BLACK-HOLE row carries an evidence path AND a proposed fix action
- [x] `git diff --stat HEAD~5 HEAD apps/ services/` returns empty (no source code modified)
- [x] Each audit committed atomically with `audit(07-01): ... (STAB-XX)` message

## Self-Check: PASSED

Files verified present:
- `.planning/phases/07-stabilisation-v2-0/AUDIT_COACH_WIRING.md` ✓
- `.planning/phases/07-stabilisation-v2-0/AUDIT_DEAD_CODE.md` ✓
- `.planning/phases/07-stabilisation-v2-0/AUDIT_ORPHAN_ROUTES.md` ✓
- `.planning/phases/07-stabilisation-v2-0/AUDIT_CONTRACT_DRIFT.md` ✓
- `.planning/phases/07-stabilisation-v2-0/AUDIT_SWALLOWED_ERRORS.md` ✓

Commits verified in `git log --oneline`:
- b8a88035 ✓
- e6fd0631 ✓
- 5bbd1287 ✓
- 3cd807aa ✓
- dad71019 ✓

Source code untouched: `git diff --stat HEAD~5 HEAD apps/ services/` empty ✓
