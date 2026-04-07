# AUDIT_COACH_WIRING — Coach tool 5-stage trace (STAB-12)

**Generated:** 2026-04-07
**Scope:** Every tool in `services/backend/app/services/coach/coach_tools.py` + every `case` in `apps/mobile/lib/widgets/coach/widget_renderer.dart`.
**Method:** Mechanical 5-stage trace. No source code modified.
**Purpose:** Feed BROKEN / MISSING rows into plan 07-04.

## Stages

1. **Backend definition** — tool declared in `coach_tools.py`
2. **LLM exposure** — tool included in the list sent to Claude
   - Backend path: `get_llm_tools()` (every non-internal `COACH_TOOLS` entry)
   - BYOK path: hardcoded list `_coachTools` in `coach_orchestrator.dart:478-532` (only `route_to_screen` + `generate_document`)
3. **Orchestrator dispatch** — tool_use result reaches the mobile chat surface
   - Backend path: backend executes `INTERNAL_TOOL_NAMES` itself, forwards others as `ragResponse.toolCalls`
   - BYOK path: `coach_orchestrator.dart:637-649` serializes 2 tools into inline text markers `[ROUTE_TO_SCREEN:{…}]` / `[GENERATE_DOCUMENT:{…}]` appended to the message body
   - `ToolCallParser.parse()` (`tool_call_parser.dart:41`) regex-extracts `[TOOL_NAME:{json}]` → `ParsedToolCall`
   - `ChatToolDispatcher.normalize()` lowercases the tool name → `RagToolCall`
4. **Renderer case** — `widget_renderer.dart:49` switch
5. **Bubble display** — `coach_message_bubble.dart:115` invokes `WidgetRenderer.build(...) ?? SizedBox.shrink()`

## Backend tool trace

| # | Tool | Category | Internal? | S1 Backend | S2 LLM exposure | S3 Orchestrator dispatch | S4 Renderer case | S5 Bubble display | Verdict | Evidence | Fix action |
|---|------|----------|-----------|-----------|-----------------|--------------------------|------------------|-------------------|---------|----------|------------|
| 1 | `show_fact_card` | read | no | PASS | PASS (get_llm_tools) | PASS via backend RAG `ragResponse.toolCalls` | PASS `case 'show_fact_card'` | PASS | **PASS** | `coach_tools.py:106`, `widget_renderer.dart:56` | — |
| 2 | `show_budget_snapshot` | read | no | PASS | PASS | PASS | PASS `case 'show_budget_snapshot'` | PASS | **PASS** | `coach_tools.py:142`, `widget_renderer.dart:62` | — |
| 3 | `show_score_gauge` | read | no | PASS | PASS | PASS | PASS `case 'show_score_gauge'` | PASS | **PASS** | `coach_tools.py:169`, `widget_renderer.dart:54` | — |
| 4 | `ask_user_input` | read | no | PASS | PASS | PASS | PASS `case 'ask_user_input'` | PASS | **PASS** | `coach_tools.py:192`, `widget_renderer.dart:66` | — |
| 5 | `retrieve_memories` | search | **yes (internal)** | PASS | n/a (stripped from LLM by backend) | n/a (backend-only) | n/a | n/a | **PASS (internal)** | `coach_tools.py:232`, `INTERNAL_TOOL_NAMES:57` | — |
| 6 | `route_to_screen` | navigate | no | PASS | PASS backend + PASS BYOK (`coach_orchestrator.dart:480`) | **BROKEN** — BYOK marker emits `intent`/`confidence`/`context_message`, NO `route` key. Backend path also forwards raw `RagToolCall` with same fields. | PASS `case 'route_to_screen'` at `widget_renderer.dart:68` BUT `_buildRouteSuggestion` reads `p['route']` (line 96) which is absent → `ToolCallParser.isValidRoute('')` false → returns `SizedBox.shrink()` at line 101 | BROKEN (shrink) | **BROKEN (SILENT-DROP at renderer)** | `coach_orchestrator.dart:639-643`, `widget_renderer.dart:96-101` | Add mobile-side `intent→route` map (D-02). Either in `chat_tool_dispatcher.dart` (currently has the “intent path not yet supported” comment at line 82) or in `_buildRouteSuggestion` before calling `isValidRoute`. |
| 7 | `set_goal` | write | no | PASS | PASS (get_llm_tools; NOT in BYOK _coachTools) | PARTIAL — Backend forwards as `RagToolCall` but BYOK path never exposes it; backend RAG path does | **MISSING** — no `case 'set_goal'` in renderer switch | MISSING (shrink) | **BROKEN (MISSING renderer case)** | `coach_tools.py:332`, renderer switch `widget_renderer.dart:49-75` (no match) | Either (a) add renderer case rendering a “goal set” confirmation chip, or (b) mark `set_goal` as backend-internal (add to `INTERNAL_TOOL_NAMES`) and have the backend mutate profile state directly. Decision required. |
| 8 | `mark_step_completed` | write | no | PASS | PASS (get_llm_tools; NOT in BYOK _coachTools) | PARTIAL — same as set_goal | **MISSING** — no `case 'mark_step_completed'` | MISSING (shrink) | **BROKEN (MISSING renderer case)** | `coach_tools.py:367`, renderer switch | Same decision as `set_goal`: add renderer confirmation case OR move to backend-internal. |
| 9 | `save_insight` | write | no | PASS | PASS (get_llm_tools; NOT in BYOK _coachTools) | PARTIAL | **MISSING** — no `case 'save_insight'` | MISSING (shrink) | **BROKEN (MISSING renderer case)** | `coach_tools.py:402`, renderer switch | Same decision. Likely best moved to backend-internal (`save_insight` is memory persistence, no UX surface needed). |
| 10 | `get_budget_status` | read | **yes (internal)** | PASS | n/a | n/a | n/a | n/a | **PASS (internal)** | `coach_tools.py:450`, `INTERNAL_TOOL_NAMES:57` | — |
| 11 | `get_retirement_projection` | read | **yes (internal)** | PASS | n/a | n/a | n/a | n/a | **PASS (internal)** | `coach_tools.py:466`, `INTERNAL_TOOL_NAMES:57` | — |
| 12 | `get_cross_pillar_analysis` | read | **yes (internal)** | PASS | n/a | n/a | n/a | n/a | **PASS (internal)** | `coach_tools.py:482`, `INTERNAL_TOOL_NAMES:57` | — |
| 13 | `get_cap_status` | read | **yes (internal)** | PASS | n/a | n/a | n/a | n/a | **PASS (internal)** | `coach_tools.py:498`, `INTERNAL_TOOL_NAMES:57` | — |
| 14 | `get_couple_optimization` | read | **yes (internal)** | PASS | n/a | n/a | n/a | n/a | **PASS (internal)** | `coach_tools.py:514`, `INTERNAL_TOOL_NAMES:57` | — |
| 15 | `get_regulatory_constant` | read | **yes (internal)** | PASS | n/a | n/a | n/a | n/a | **PASS (internal)** | `coach_tools.py:536`, `INTERNAL_TOOL_NAMES:57` | — |
| 16 | `record_check_in` | write | no | PASS | PASS backend path. **BROKEN BYOK** — absent from `_coachTools` at `coach_orchestrator.dart:478` | Backend path: forwarded as `RagToolCall`. BYOK path: never emitted → tool never reaches mobile. | PASS `case 'record_check_in'` at `widget_renderer.dart:72` (renderer exists and is correct — `_buildCheckInSummaryCard`) | PASS (if dispatched) | **BROKEN (BYOK LLM exposure missing)** | `coach_tools.py:574`, `coach_orchestrator.dart:478-532` | D-04 fix: add `record_check_in` to the BYOK `_coachTools` list AND re-expose `toolCalls` on `CoachLlmService.chat()` return (currently dropped at `coach_llm_service.dart:321-328`, the `return CoachResponse(...)` rebuild omits the `toolCalls:` field). |
| 17 | `generate_financial_plan` | write | no | PASS | PASS backend path. **BROKEN BYOK** — absent from `_coachTools` | Backend path: forwarded. BYOK path: never emitted. | PASS `case 'generate_financial_plan'` at `widget_renderer.dart:70` (renderer exists — `_buildPlanPreviewCard`) | PASS (if dispatched) | **BROKEN (BYOK LLM exposure missing)** | `coach_tools.py:612`, `coach_orchestrator.dart:478-532` | D-04 fix: add `generate_financial_plan` to the BYOK `_coachTools` list AND re-expose `toolCalls` on `CoachLlmService.chat()` return. |
| 18 | `generate_document` | write | no | PASS | PASS backend + PASS BYOK (`coach_orchestrator.dart:503`) | Backend path: forwarded. BYOK path: emits `[GENERATE_DOCUMENT:{…}]` marker at `coach_orchestrator.dart:644-647`; parser normalizes name to `generate_document`. | **MISSING** — no `case 'generate_document'` in `widget_renderer.dart:49-75` switch | MISSING (shrink) | **BROKEN (MISSING renderer case)** | `coach_tools.py:674`, `widget_renderer.dart:49-75` | D-03 fix: add `case 'generate_document': return _buildDocumentGenerationCard(...)` returning a `DocumentGenerationCard` (create if absent — minimal chip + label + onTap). |

## Renderer → backend cross-product (orphan renderer cases)

The renderer switch (`widget_renderer.dart:49-75`) has 12 cases. Backend tools = 18. Cross-product:

| Renderer case | Matching backend tool? | Verdict | Evidence | Fix action |
|---------------|------------------------|---------|----------|------------|
| `show_retirement_comparison` | **NO** backend tool of this name in `coach_tools.py` | **ORPHAN case** | `widget_renderer.dart:50` | Either (a) add `show_retirement_comparison` as a backend tool, or (b) delete the renderer case + helper `_buildRetirementComparison` (lines 139-152). Recommend DELETE — coverage handled by `show_comparison_card` / `show_budget_snapshot`. |
| `show_budget_overview` | **NO** backend tool | **ORPHAN case** | `widget_renderer.dart:51` | DELETE case + `_buildBudgetOverview` (154-167). Overlaps with `show_budget_snapshot`. |
| `show_score_gauge` | YES (`coach_tools.py:169`) | PASS | — | — |
| `show_fact_card` | YES | PASS | — | — |
| `show_choice_comparison` | **NO** backend tool | **ORPHAN case** | `widget_renderer.dart:58` | DELETE or define backend tool. |
| `show_pillar_breakdown` | **NO** backend tool | **ORPHAN case** | `widget_renderer.dart:60` | DELETE or define backend tool. |
| `show_budget_snapshot` | YES | PASS | — | — |
| `show_comparison_card` | **NO** backend tool | **ORPHAN case** | `widget_renderer.dart:64` | DELETE or define backend tool. |
| `ask_user_input` | YES | PASS | — | — |
| `route_to_screen` | YES (BROKEN — see row 6) | BROKEN | — | See row 6 |
| `generate_financial_plan` | YES (BROKEN BYOK — see row 17) | BROKEN | — | See row 17 |
| `record_check_in` | YES (BROKEN BYOK — see row 16) | BROKEN | — | See row 16 |

## Summary

| Category | Count |
|----------|-------|
| Backend tools total | 18 |
| Internal (backend-only) | 7 |
| User-visible tools | 11 |
| PASS (full 5-stage) | 4 (`show_fact_card`, `show_budget_snapshot`, `show_score_gauge`, `ask_user_input`) |
| BROKEN (silent drop at renderer) | 1 (`route_to_screen`) |
| BROKEN (missing renderer case) | 4 (`set_goal`, `mark_step_completed`, `save_insight`, `generate_document`) |
| BROKEN (BYOK LLM exposure missing) | 2 (`record_check_in`, `generate_financial_plan`) |
| Renderer orphan cases (no backend tool) | 5 (`show_retirement_comparison`, `show_budget_overview`, `show_choice_comparison`, `show_pillar_breakdown`, `show_comparison_card`) |

**7 BROKEN findings drive STAB-01..04 fixes in plan 07-02** (coach tool wiring).
**5 orphan renderer cases drive plan 07-04 cleanup decisions** (delete vs define backend tool).
**Decision needed for `set_goal` / `mark_step_completed` / `save_insight`**: render confirmation UI OR mark backend-internal.
