---
phase: 02-tool-dispatch
verified: 2026-04-05T00:00:00Z
status: human_needed
score: 3/4 roadmap success criteria programmatically verified
re_verification: false
human_verification:
  - test: "Open coach chat, type 'comment fonctionne mon LPP?', send with SLM or BYOK"
    expected: "An inline ChatFactCard widget appears in the message bubble — not a text-only response"
    why_human: "Requires live LLM response with a show_fact_card tool call; cannot verify without running app + LLM"
  - test: "Trigger a route_to_screen tool call (e.g. ask 'montre-moi le simulateur rente vs capital'), then tap the RouteSuggestionCard"
    expected: "The app navigates to /rente-vs-capital (or whichever valid route the card presents)"
    why_human: "Tap/navigation behavior cannot be verified without running the app; GoRouter push requires a real shell"
---

# Phase 2: Tool Dispatch Verification Report

**Phase Goal:** Coach tool calls (show_fact_card, route_to_screen, show_score_gauge, etc.) reach the Flutter UI and render the appropriate inline widgets
**Verified:** 2026-04-05
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ChatToolDispatcher exists as a distinct class, parses tool markers, and dispatches to UI handler (SC4 / TDP-02) | VERIFIED | `apps/mobile/lib/services/coach/chat_tool_dispatcher.dart` — 90 lines, `normalize()` / `filterRag()` / `resolveRoute()` all implemented and tested |
| 2 | SLM + BYOK paths populate ChatMessage.richToolCalls via ChatToolDispatcher.normalize() (SC4 / TDP-01) | VERIFIED | `coach_chat_screen.dart` lines 706+764: 2 occurrences of `ChatToolDispatcher.normalize(parseResult.toolCalls)` with `richToolCalls: richCalls` stored in ChatMessage |
| 3 | route_to_screen tool call renders a RouteSuggestionCard inline — no auto-push navigation (SC2 / TDP-03) | VERIFIED (code path) | `widget_renderer.dart` `case 'route_to_screen':` → `_buildRouteSuggestion()` → `RouteSuggestionCard`; whitelist validation via `ToolCallParser.isValidRoute()`; CoachMessageBubble loops `msg.richToolCalls` calling `WidgetRenderer.build()` |
| 4 | Widget rendering uses LLM tool decisions, not keyword matching (SC3 / TDP-04) | VERIFIED | `_buildRichWidget` deleted from coach_chat_screen.dart (grep returns 0 matches); `coach_rich_widgets.dart` has 0 active imports in lib/; CoachMessageBubble rendering path goes exclusively through `richToolCalls` → `WidgetRenderer` |
| 5 | Live FactCard appears in chat bubble from LLM response (SC1) | ? HUMAN NEEDED | Requires live LLM call with show_fact_card tool output — not verifiable programmatically |
| 6 | Tapping RouteSuggestionCard actually navigates to the suggested screen (SC2 tap behavior) | ? HUMAN NEEDED | Widget renders correctly (test-verified), but tap → GoRouter push requires running app |

**Score:** 4/4 programmatically verifiable truths confirmed. 2 truths require human verification (live LLM behavior + UI tap navigation).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/mobile/lib/services/coach/chat_tool_dispatcher.dart` | ChatToolDispatcher with normalize/filterRag/resolveRoute | VERIFIED | 90 lines, all 3 methods present, imports rag_service + tool_call_parser |
| `apps/mobile/test/services/coach/chat_tool_dispatcher_test.dart` | Unit tests for ChatToolDispatcher | VERIFIED | 152 lines, 18 tests across normalize/filterRag/resolveRoute groups |
| `apps/mobile/lib/widgets/coach/widget_renderer.dart` | WidgetRenderer with route_to_screen case | VERIFIED | 388 lines, `case 'route_to_screen':` present, `_buildRouteSuggestion()` implemented |
| `apps/mobile/test/widgets/coach/widget_renderer_test.dart` | Widget tests for route_to_screen | VERIFIED | 226 lines, 8 tests covering valid/invalid/missing route, prefill, context_message, narrative fallback, is_partial |
| `apps/mobile/lib/screens/coach/coach_chat_screen.dart` | Rewired with ChatToolDispatcher, legacy paths removed | VERIFIED | 2 ChatToolDispatcher.normalize() calls; no _executeToolCalls; no _buildRichWidget; no CoachRichWidgetBuilder import |
| `apps/mobile/lib/widgets/coach/coach_message_bubble.dart` | No richWidget parameter, renders via richToolCalls | VERIFIED | 541 lines; no `richWidget` field; loops `msg.richToolCalls` → `WidgetRenderer.build()` at lines 111-124 |
| `apps/mobile/test/widgets/coach/coach_message_bubble_test.dart` | Tests confirming richToolCalls pipeline | VERIFIED | 237 lines, 9 tests covering FactCard rendering, route_to_screen valid/invalid, ChatMessage.richToolCalls field, hasRichToolCalls, no keyword fallback |
| `apps/mobile/lib/widgets/coach/coach_rich_widgets.dart` | DELETED per plan | WARNING | File exists on disk (230 lines); however it has 0 active imports in lib/ — it is dead code, not reachable from any execution path. The file is an orphan, not a wired fallback. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `coach_chat_screen.dart` | `chat_tool_dispatcher.dart` | `ChatToolDispatcher.normalize(parseResult.toolCalls)` | WIRED | Lines 706, 764 — both SLM and BYOK paths |
| `coach_chat_screen.dart` | `coach_message_bubble.dart` | `CoachMessageBubble(message: msg, ...)` — msg carries richToolCalls | WIRED | Line 1407-1415; msg is a ChatMessage that contains richToolCalls set by the normalize() calls |
| `coach_message_bubble.dart` | `widget_renderer.dart` | `import + WidgetRenderer.build(context, toolCall, ...)` | WIRED | Line 10 import; lines 111-124 loop rendering |
| `widget_renderer.dart` | `route_suggestion_card.dart` | `import + RouteSuggestionCard(...)` in _buildRouteSuggestion | WIRED | Line 7 import; line 84 construction |
| `chat_tool_dispatcher.dart` | `tool_call_parser.dart` | `import + ToolCallParser.isValidRoute()` | WIRED | Line 12 import; line 87 call in resolveRoute() |
| `chat_tool_dispatcher.dart` | `rag_service.dart` | `import + RagToolCall(name:, input:)` | WIRED | Line 13 import; line 53 construction in normalize() |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `CoachMessageBubble` | `msg.richToolCalls` | ChatToolDispatcher.normalize() called from CoachChatScreen on every LLM response | Yes — populated from actual LLM text-marker parsing in real-time | FLOWING |
| `WidgetRenderer._buildFactCard` | `p['value']`, `p['eyebrow']`, `p['description']` | LLM tool call input map from Claude response | Yes — parameters come directly from LLM tool_use output | FLOWING |
| `WidgetRenderer._buildRouteSuggestion` | `p['route']`, `p['context_message']` | LLM tool call input map | Yes — route validated against whitelist before rendering | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| ChatToolDispatcher.normalize() converts SCREAMING_SNAKE to snake_case | `flutter test test/services/coach/chat_tool_dispatcher_test.dart` | 18 tests passed | PASS |
| ChatToolDispatcher caps at 5 | Part of above test run | cap-at-5 test green | PASS |
| WidgetRenderer route_to_screen case renders RouteSuggestionCard | `flutter test test/widgets/coach/widget_renderer_test.dart` | 8 tests passed | PASS |
| CoachMessageBubble richToolCalls pipeline | `flutter test test/widgets/coach/coach_message_bubble_test.dart` | 9 tests passed | PASS |
| All 35 phase 02 tests | Combined test run | 35/35 passed | PASS |
| Live FactCard from LLM response | Not runnable without app + LLM | — | SKIP (human) |
| RouteSuggestionCard tap navigation | Not runnable without app shell | — | SKIP (human) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| TDP-01 | 02-01, 02-02 | Coach tool calls reach UI and render appropriate widgets | SATISFIED | richToolCalls pipeline: normalize → ChatMessage → CoachMessageBubble → WidgetRenderer confirmed; 35 tests green |
| TDP-02 | 02-01, 02-02 | ChatToolDispatcher created — parses tool markers, dispatches to UI handler | SATISFIED | `chat_tool_dispatcher.dart` exists with normalize/filterRag/resolveRoute; wired in both SLM and BYOK paths |
| TDP-03 | 02-01, 02-02 | RoutePlanner suggestions rendered as tappable cards in chat (not just logged) | SATISFIED (code); NEEDS HUMAN (tap) | RouteSuggestionCard widget renders correctly; tap→navigation requires human verification |
| TDP-04 | 02-02 | CoachRichWidgetBuilder uses LLM tool decisions (not keyword matching) | SATISFIED | keyword-matching `_buildRichWidget` deleted; `coach_rich_widgets.dart` has zero active imports; only `richToolCalls` → `WidgetRenderer` path remains |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `apps/mobile/lib/widgets/coach/coach_rich_widgets.dart` | 1-230 | Orphan file — exists on disk with full implementation but zero imports in lib/ | Warning | Not callable; no execution path reaches it. Dead code risk: a future developer might accidentally import it, re-enabling keyword matching. Should be deleted to eliminate confusion. |

### Human Verification Required

#### 1. Live FactCard from LLM response (SC1)

**Test:** Open coach chat with an active API key. Send the message "comment fonctionne mon LPP?". Wait for response.
**Expected:** The response bubble contains an inline ChatFactCard widget (not just text). The card should show an eyebrow label, a value, and a description.
**Why human:** Requires a live Claude API response that includes a `show_fact_card` tool call. The tool call text markers must be in the response, ToolCallParser must parse them, ChatToolDispatcher.normalize() must convert them, and WidgetRenderer must render the correct widget. Each step is individually verified in tests — but the end-to-end LLM → widget path requires a real API call.

#### 2. RouteSuggestionCard tap navigates to target screen (SC2 tap behavior)

**Test:** Trigger a `route_to_screen` tool call response in chat (e.g., ask "montre-moi le simulateur rente vs capital"). Confirm a RouteSuggestionCard appears. Tap the card's CTA button.
**Expected:** The app navigates to the suggested route (e.g., `/rente-vs-capital`). The target screen loads correctly without a crash or "route not found" error.
**Why human:** Widget presence and routing wiring are test-verified. The actual tap → GoRouter push → screen mount sequence requires a running app with a real navigation shell.

### Gaps Summary

No hard gaps blocking goal achievement. All programmatically verifiable pipeline components exist, are substantive, and are wired end-to-end.

One low-priority warning: `apps/mobile/lib/widgets/coach/coach_rich_widgets.dart` was supposed to be deleted per Plan 02-02 Task 2 acceptance criteria but remains on disk. It has zero active imports and is unreachable from any execution path — the keyword-matching behavior TDP-04 required to eliminate is genuinely not reachable. This is a housekeeping gap (dead code), not a functional gap. It does not block any requirement.

Two items require human verification before the phase can be marked fully passed:
1. Live LLM response producing a FactCard widget in chat (SC1 end-to-end)
2. RouteSuggestionCard tap → GoRouter navigation succeeds (SC2 tap behavior)

---

_Verified: 2026-04-05_
_Verifier: Claude (gsd-verifier)_
