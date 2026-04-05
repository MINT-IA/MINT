# Phase 2: Tool Dispatch - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire coach tool calls (show_fact_card, route_to_screen, show_score_gauge, etc.) to the Flutter UI so LLM outputs reach the user as rich inline widgets — not text-only responses. This phase creates the dispatch infrastructure; it does not add new tool types or modify the backend.

</domain>

<decisions>
## Implementation Decisions

### Dispatch Architecture
- **D-01:** Create `ChatToolDispatcher` as a standalone class in `lib/services/coach/chat_tool_dispatcher.dart`. Single entry point that accepts both `ParsedToolCall` (from text markers) and `RagToolCall` (from backend tool_use), normalizes to a common internal type, and dispatches via one switch.
- **D-02:** Keep the `[TOOL_NAME:{json}]` text-marker format for the SLM streaming path. `ChatToolDispatcher` normalizes both formats internally. No backend changes needed.
- **D-03:** Remove the inline `_executeToolCalls` method from `CoachChatScreen`. All dispatch goes through `ChatToolDispatcher`.

### Widget Rendering Strategy
- **D-04:** Remove `CoachRichWidgetBuilder` entirely. All widget rendering goes through `ChatToolDispatcher` → `WidgetRenderer`. If the LLM doesn't call a tool, no widget appears. Clean break from keyword matching.
- **D-05:** SLM text-marker tool calls (e.g., `[SHOW_FACT_CARD:{...}]`) are normalized to `RagToolCall` by `ChatToolDispatcher` and added to the message's `richToolCalls` list. Both SLM and BYOK paths produce identical widget rendering via `WidgetRenderer`.

### Route Suggestion UX
- **D-06:** `route_to_screen` always renders a `RouteSuggestionCard` — the coach PROPOSES, the user DECIDES. No auto-push. Replace the current `context.push(route)` with card rendering.
- **D-07:** `RouteSuggestionCard` passes prefill data from tool call arguments to the target screen via GoRouter extras. This prepares the ground for Phase 6 (Calculator Wiring).

### Error & Fallback Handling
- **D-08:** Unknown tool names are silently ignored. No error shown to user. Debug log only. The message text displays normally without the widget.
- **D-09:** `ToolCallParser.validRoutes` whitelist continues to reject unknown route paths. Behavior for rejected routes at Claude's discretion (silent reject or disabled card).

### Claude's Discretion
- Widget placement relative to message bubble (inline below text vs separate card) — current inline pattern likely best but open to change
- Handling of invalid route paths: silent reject with debug log vs disabled-state RouteSuggestionCard
- Internal `ToolAction` type design (fields, naming)
- Test strategy and granularity

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Tool Dispatch Core
- `apps/mobile/lib/services/coach/tool_call_parser.dart` — Existing text-marker parser, `ParsedToolCall` class, `validRoutes` whitelist
- `apps/mobile/lib/widgets/coach/widget_renderer.dart` — Existing widget renderer, handles 9 tool types via `RagToolCall`
- `apps/mobile/lib/widgets/coach/coach_rich_widgets.dart` — Keyword-matching builder TO BE REMOVED (D-04)
- `apps/mobile/lib/widgets/coach/route_suggestion_card.dart` — Existing route card with prefill, warning banners, ReturnContract V2

### Chat Integration
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — Main chat screen, `_executeToolCalls` method (to be replaced), `CoachRichWidgetBuilder.build()` call at ~line 1450 (to be removed)
- `apps/mobile/lib/widgets/coach/coach_message_bubble.dart` — Renders `richToolCalls` via `WidgetRenderer` at ~line 117
- `apps/mobile/lib/services/coach_llm_service.dart` — `ChatMessage` class with `richToolCalls: List<RagToolCall>` field

### Backend (read-only context)
- `apps/mobile/lib/services/rag_service.dart` — `RagToolCall` class definition, `RagResponse` with tool calls
- `apps/mobile/lib/services/coach/coach_orchestrator.dart` — Backend tool definitions (`route_to_screen`, `generate_document`), tool_use → text-marker conversion

### Tests
- `apps/mobile/test/services/tool_call_parser_test.dart` — Existing parser tests
- `apps/mobile/test/screens/coach/coach_chat_test.dart` — Chat screen tests

### UX & Architecture
- `docs/NAVIGATION_GRAAL_V10.md` — Route table, Wire Spec V2 archived routes
- `apps/mobile/lib/app.dart` — GoRouter route definitions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ToolCallParser` — already parses text markers correctly, just needs its dispatch output routed through ChatToolDispatcher
- `WidgetRenderer` — already handles 9 tool types (show_retirement_comparison, show_budget_overview, show_score_gauge, show_fact_card, show_choice_comparison, show_pillar_breakdown, show_budget_snapshot, show_comparison_card, ask_user_input). Fully functional.
- `RouteSuggestionCard` — fully implemented with prefill, partial-data warnings, return contract V2, entrance animation. Just not being used for ROUTE_TO_SCREEN dispatches.
- `RagToolCall` — simple data class (name + input map) that WidgetRenderer consumes. Easy to create from ParsedToolCall.

### Established Patterns
- `CoachMessageBubble` already iterates `msg.richToolCalls` and calls `WidgetRenderer.build()` for each — the rendering pipeline works
- `ToolCallParser.validRoutes` enforces a route whitelist — security pattern to preserve
- Tool calls capped at `_maxToolCallsPerResponse` to prevent flooding — cap logic to preserve in ChatToolDispatcher

### Integration Points
- `CoachChatScreen._handleSlmStreaming()` at line 691: parses tool calls from SLM response
- `CoachChatScreen._handleStandardResponse()` at line 752: parses tool calls from BYOK response
- Both call `_executeToolCalls()` — this is the single point to rewire to ChatToolDispatcher
- `ChatMessage` constructor already accepts `richToolCalls` — just need to populate it from text-marker path too

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-tool-dispatch*
*Context gathered: 2026-04-05*
