---
phase: 07-stabilisation-v2-0
plan: 02
subsystem: coach-tool-wiring
tags: [facade-audit, coach, byok, widget-renderer, stab-01, stab-02, stab-03, stab-04, stab-11]
requirements: [STAB-01, STAB-02, STAB-03, STAB-04, STAB-11]
depends_on: [07-01]
dependency_graph:
  requires:
    - MintScreenRegistry.findByIntentStatic (existing, canonical intent→route map)
    - CoachOrchestrator.byok_tool_list (extended from 2 → 4 tools)
    - CoachLlmService.chat.return.toolCalls (re-exposed)
    - WidgetRenderer.switch (add generate_document case)
  provides:
    - coach_tool_choreography_e2e_guard
    - intent_to_route_resolution_mobile_side
    - byok_tool_exposure_parity_with_backend
  affects:
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart (merge structured + marker tool calls)
tech-stack:
  added: []
  patterns: [facade-audit-guard, renderer-is-sot, structured-tool-calls-over-markers]
key-files:
  created:
    - apps/mobile/test/integration/coach_tool_choreography_test.dart
  modified:
    - apps/mobile/lib/services/coach/chat_tool_dispatcher.dart
    - apps/mobile/lib/widgets/coach/widget_renderer.dart
    - apps/mobile/lib/services/coach/coach_orchestrator.dart
    - apps/mobile/lib/services/coach_llm_service.dart
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart
    - .planning/REQUIREMENTS.md
decisions:
  - D-02 applied: intent→route resolved mobile-side via MintScreenRegistry (canonical, no duplication)
  - D-03 applied: generate_document uses a minimal inline card (chip + CTA → /documents); full pipeline deferred
  - D-04 applied: _coachTools expanded to 4; CoachLlmService.chat() re-exposes toolCalls; screen merges structured+marker paths
  - D-05 applied: E2E test uses real widget tree, one test per tool, no renderer mocks
metrics:
  duration_minutes: ~45
  tasks_completed: 3
  commits: 3
  files_modified: 5
  files_created: 1
  tests_added: 4
  tests_passing: "4/4"
  analyze_issues: 0
completed: 2026-04-07
---

# Phase 7 Plan 02: Coach tool wiring end-to-end — Summary

Wired all 4 coach tools (route_to_screen, generate_document, generate_financial_plan, record_check_in) end-to-end from BYOK orchestrator emit to user-visible widget in CoachMessageBubble, with an integration test locking the chain against future regressions.

## Requirements closed

| ID | Requirement | Status | Evidence |
|----|------------|--------|----------|
| STAB-01 | route_to_screen rendered end-to-end | DONE | `chat_tool_dispatcher.dart::resolveRouteFromIntent`, `widget_renderer.dart::_buildRouteSuggestion` intent fallback, test `STAB-01` |
| STAB-02 | generate_document rendered visible | DONE | `widget_renderer.dart::_buildDocumentGenerationCard`, test `STAB-02` |
| STAB-03 | generate_financial_plan exposed BYOK + toolCalls re-exposed | DONE | `coach_orchestrator.dart::_coachTools` extended, `coach_llm_service.dart:321` re-exposes `toolCalls`, test `STAB-03` |
| STAB-04 | record_check_in exposed BYOK + toolCalls re-exposed | DONE | same as STAB-03, test `STAB-04` |
| STAB-11 | E2E choreography test for all 4 tools | DONE | `test/integration/coach_tool_choreography_test.dart`, 4/4 passing |

## What changed and why

### STAB-01 — route_to_screen intent resolution

**Root cause:** Backend `coach_tools.py` `route_to_screen` emits `{intent, confidence, context_message}` without an explicit `route` field. Mobile `widget_renderer.dart::_buildRouteSuggestion` read `p['route']`, found `''`, failed `ToolCallParser.isValidRoute('')`, and returned `SizedBox.shrink()`. The `chat_tool_dispatcher.dart:82` source comment explicitly said "intent path is not yet supported".

**Fix:** `ChatToolDispatcher.resolveRouteFromIntent(intent)` now looks up `MintScreenRegistry.findByIntentStatic(intent)` (canonical intent→route map already used by `RoutePlanner`) and validates the resulting route against the existing security whitelist. `_buildRouteSuggestion` falls back to this resolver when the backend omits `route`. No new map was introduced — `MintScreenRegistry` is the single source of truth.

### STAB-02 — generate_document renderer case

**Root cause:** `coach_orchestrator.dart:644` emitted `[GENERATE_DOCUMENT:{…}]` markers which the parser extracted, but the renderer switch at `widget_renderer.dart:49` had no `case 'generate_document'`. Fell through to `default: null` → `SizedBox.shrink()` in the bubble.

**Fix:** Added `case 'generate_document': return _buildDocumentGenerationCard(...)`. The card is minimal per scope — document-type label (fiscal_declaration / pension_fund_letter / lpp_buyback_request mapped to French labels), context message from the LLM, and a "Préparer le document" CTA routing to `/documents` where the full FormPrefill / LetterGeneration pipeline runs. Full pipeline wiring is out of scope for 07-02 (surgical fix only per plan).

### STAB-03 + STAB-04 — BYOK tool exposure + toolCalls re-exposure

**Root cause:** Two cascading facade-sans-cablage bugs:

1. `coach_orchestrator.dart::_coachTools` only listed `route_to_screen` and `generate_document`. Claude on the BYOK path could never call `generate_financial_plan` or `record_check_in` — the renderer cases at `widget_renderer.dart:70/74` were implemented but unreachable.
2. `coach_llm_service.dart:321-328` rebuilt `CoachResponse` and silently dropped the `toolCalls:` field — even though the orchestrator populated it. Structured tool calls from BYOK never reached the screen.

**Fix:**
- `_coachTools` extended to 4 entries with full Anthropic tool schemas for `generate_financial_plan` and `record_check_in`.
- `CoachLlmService.chat()` now passes `toolCalls: orchestratorResponse.toolCalls` through.
- `coach_chat_screen.dart::_handleStandardResponse` merges `response.toolCalls` (structured BYOK path) with `parseResult.toolCalls` (legacy marker path) into `richToolCalls`, capped at 5. Both transports now feed `WidgetRenderer` via `CoachMessageBubble`.

### STAB-11 — E2E choreography guard

New integration test `apps/mobile/test/integration/coach_tool_choreography_test.dart` pumps `CoachMessageBubble` against a real widget tree (`MaterialApp.router` + `MultiProvider`), one test per tool. Each test constructs a `RagToolCall` as-if-from-Claude, attaches it to a `ChatMessage.richToolCalls`, and asserts the expected real widget appears in the tree. Removing any of the 4 renderer cases (or reverting to `SizedBox.shrink`) will fail the corresponding test. This is the facade-sans-cablage guard v2.0 lacked.

## Deviations from Plan

**None.** Plan 07-02 tasks executed exactly as specified in the PLAN file (D-01..D-05 applied verbatim).

### Intentional tactical choice (not a deviation)

Task 2 in the plan suggested "iterate over the returned toolCalls and dispatch each one via the same path used for marker-based tools (i.e., emit the corresponding `[TOOL:…]` marker OR call the dispatcher directly — match the existing pattern)". I chose to **dispatch structured toolCalls directly** at the screen layer (merging `response.toolCalls` into `richToolCalls`) rather than round-tripping them through the brittle marker transport. Reasons:

1. `ToolCallParser` regex `\[([A-Z_]+):\{(.*?)\}\]` is non-greedy on the JSON body. For `record_check_in` with nested `versements: {...}`, marker round-trip is fragile — the renderer already accepts structured `RagToolCall.input` as a `Map<String, dynamic>`, so bypassing the marker stringification is both safer and simpler.
2. The plan explicitly says "CoachLlmService.chat() must re-expose toolCalls on return so the orchestrator can dispatch them" — structured dispatch IS the intended path.
3. The existing marker emission for `route_to_screen` and `generate_document` at `coach_orchestrator.dart:637-650` is untouched, preserving the legacy transport for the 2 original tools. No redesign.

## Out-of-scope findings (routed to 07-04)

The `AUDIT_COACH_WIRING.md` and `AUDIT_CONTRACT_DRIFT.md` reports from 07-01 identified additional broken tools and a root-cause schema drift that are NOT in the STAB-01..04 scope of this plan. Explicitly deferred to 07-04:

| Finding | Audit row | Disposition for 07-04 |
|---------|-----------|-----------------------|
| `RAGQueryRequest` missing `tools` field (REQUEST-DROP) | AUDIT_CONTRACT_DRIFT E1 | Add `tools: Optional[list[dict]]` + thread through `rag.py` + `services/rag/orchestrator.py`. This is the backend root cause of BYOK tool exposure failing via `/rag/query`. |
| `RAGQueryResponse` missing `tool_calls` field (PHANTOM) | AUDIT_CONTRACT_DRIFT E1 | Add `tool_calls: Optional[list[dict]]` + forward from orchestrator. Brings RAGQueryResponse in line with already-correct `CoachChatResponse`. |
| `set_goal` missing renderer case | AUDIT_COACH_WIRING row 7 | Decision required: add confirmation chip renderer OR move to `INTERNAL_TOOL_NAMES`. |
| `mark_step_completed` missing renderer case | AUDIT_COACH_WIRING row 8 | Same decision as `set_goal`. |
| `save_insight` missing renderer case | AUDIT_COACH_WIRING row 9 | Likely move to `INTERNAL_TOOL_NAMES` (memory persistence has no UX surface). |
| 5 orphan renderer cases (`show_retirement_comparison`, `show_budget_overview`, `show_choice_comparison`, `show_pillar_breakdown`, `show_comparison_card`) | AUDIT_COACH_WIRING cross-product | Delete or define corresponding backend tools. Cleanup pass for 07-04. |
| `route_to_screen` `confidence` field unused in renderer | AUDIT_CONTRACT_DRIFT E1 bonus | P1 — use to gate suggestion / fallback to clarifying question card. |
| `DocumentCard` full pipeline wiring | this plan (deferred) | 07-02 renders a minimal chip; full `FormPrefillService` / `LetterGenerationService` + `AgentValidationGate` + `DocumentCard` pipeline wiring is a 07-04 task if still needed after the schema fix unlocks the backend path. |

**Important:** STAB-01..04 are now functional on the BYOK path (structured toolCalls flow directly through `CoachLlmService.chat` return → screen → renderer). The backend schema drift documented above primarily affects the `/rag/query`-based backend-RAG path; fixing the schema in 07-04 will additionally unlock that transport for all 7 user-visible tools simultaneously.

## Verification

```
cd apps/mobile
flutter analyze lib/services/coach/ lib/services/coach_llm_service.dart \
  lib/widgets/coach/ lib/screens/coach/coach_chat_screen.dart \
  test/integration/coach_tool_choreography_test.dart
# → No issues found (5 items analyzed)

flutter test test/integration/coach_tool_choreography_test.dart
# → 00:00 +4: All tests passed!
```

## Commits

| # | Hash | Type | Summary |
|---|------|------|---------|
| 1 | `52d8e9bc` | fix(coach) | wire route_to_screen + generate_document end-to-end (STAB-01, STAB-02) |
| 2 | `e782a437` | fix(coach) | expose generate_financial_plan + record_check_in via BYOK (STAB-03, STAB-04) |
| 3 | `55c5731b` | test(coach) | add end-to-end tool choreography integration test (STAB-11) |

## Known stubs

None. All 4 tool paths now produce real user-visible widgets. The `generate_document` card routes to `/documents` (pre-existing screen) for the full generation pipeline — this is a routing continuation, not a stub.

## Threat flags

None. No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries were introduced. Security whitelist (`ToolCallParser.validRoutes`) continues to gate all resolved routes — the intent resolver explicitly re-validates via `isValidRoute` after `MintScreenRegistry` lookup.

## Self-Check: PASSED

- Files created (1):
  - `apps/mobile/test/integration/coach_tool_choreography_test.dart` — FOUND
- Files modified (6):
  - `apps/mobile/lib/services/coach/chat_tool_dispatcher.dart` — FOUND
  - `apps/mobile/lib/widgets/coach/widget_renderer.dart` — FOUND
  - `apps/mobile/lib/services/coach/coach_orchestrator.dart` — FOUND
  - `apps/mobile/lib/services/coach_llm_service.dart` — FOUND
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — FOUND
  - `.planning/REQUIREMENTS.md` — FOUND (STAB-01..04, STAB-11 checkboxes + traceability table updated)
- Commits (3): `52d8e9bc`, `e782a437`, `55c5731b` — all reachable via `git log`
- Tests: 4/4 passing
- Analyze: 0 issues on all 5 production + 1 test file
