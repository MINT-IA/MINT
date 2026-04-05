---
phase: 02-tool-dispatch
plan: "01"
subsystem: coach-tool-dispatch
tags: [flutter, coach, tool-dispatch, widget-renderer, security]
dependency_graph:
  requires: []
  provides: [ChatToolDispatcher, WidgetRenderer.route_to_screen]
  affects: [CoachChatScreen, WidgetRenderer]
tech_stack:
  added: []
  patterns: [static-utility-class, tdd-red-green, whitelist-validation]
key_files:
  created:
    - apps/mobile/lib/services/coach/chat_tool_dispatcher.dart
    - apps/mobile/test/services/coach/chat_tool_dispatcher_test.dart
    - apps/mobile/test/widgets/coach/widget_renderer_test.dart
  modified:
    - apps/mobile/lib/widgets/coach/widget_renderer.dart
decisions:
  - ChatToolDispatcher is a static utility class (no instantiation needed) — same pattern as ToolCallParser
  - _maxToolCallsPerResponse = 5 mirrors existing cap in CoachChatScreen._executeToolCalls for consistency
  - resolveRoute returns null for intent path — deferred to Phase 6 per RESEARCH.md Open Question #1
  - _buildRouteSuggestion returns SizedBox.shrink() (not null) for invalid routes — caller gets a widget, not null, for safer rendering
metrics:
  duration_minutes: 25
  completed_date: "2026-04-05"
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 1
  tests_added: 26
---

# Phase 02 Plan 01: Tool Dispatch Foundation Summary

ChatToolDispatcher utility class + route_to_screen case in WidgetRenderer with whitelist route validation and 5-call cap.

## Tasks Completed

| # | Task | Commit | Result |
|---|------|--------|--------|
| 1 | Create ChatToolDispatcher class with tests | 87b87087 | 18 tests green |
| 2 | Add route_to_screen case to WidgetRenderer | d7f3e204 | 8 tests green, 0 regressions |

## What Was Built

### ChatToolDispatcher (`apps/mobile/lib/services/coach/chat_tool_dispatcher.dart`)

Static utility class with three methods:

- `normalize(List<ParsedToolCall>)` — Converts SCREAMING_SNAKE_CASE ParsedToolCall list (SLM text-marker path) to snake_case RagToolCall list (BYOK format). Caps at 5 entries (T-02-02 DoS mitigation). SHOW_FACT_CARD becomes show_fact_card, matching WidgetRenderer switch cases exactly.
- `filterRag(List<RagToolCall>)` — Caps BYOK RagToolCall list at 5 entries. Pass-through if already within limit.
- `resolveRoute(Map<String, dynamic>)` — Reads `input['route']` and validates via ToolCallParser.isValidRoute() whitelist (T-02-01 Tampering mitigation). Returns route if valid, null otherwise. Intent path returns null (deferred Phase 6).

### WidgetRenderer — route_to_screen case (`apps/mobile/lib/widgets/coach/widget_renderer.dart`)

Added `case 'route_to_screen':` that delegates to new `_buildRouteSuggestion()` static method. Validates route via ToolCallParser.isValidRoute() (T-02-03), returns SizedBox.shrink() for invalid routes. Passes contextMessage (with narrative fallback), prefill, and isPartial to RouteSuggestionCard. No automatic navigation — the coach proposes, the user decides.

## Security Coverage

All three threat model mitigations implemented:

| Threat ID | Status | Implementation |
|-----------|--------|----------------|
| T-02-01 Tampering (resolveRoute) | Mitigated | ToolCallParser.isValidRoute() whitelist in ChatToolDispatcher.resolveRoute() |
| T-02-02 DoS (normalize) | Mitigated | _maxToolCallsPerResponse = 5 cap in normalize() and filterRag() |
| T-02-03 Tampering (_buildRouteSuggestion) | Mitigated | ToolCallParser.isValidRoute() check before RouteSuggestionCard construction |

## Tests

- 18 unit tests for ChatToolDispatcher (normalize, filterRag, resolveRoute — all edge cases)
- 8 widget tests for WidgetRenderer.route_to_screen (valid/invalid/missing route, prefill, contextMessage, narrative fallback, is_partial)
- route_suggestion_card_test: 17 tests still green (0 regressions)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. ChatToolDispatcher.resolveRoute() intentionally returns null for `intent` key — this is documented as deferred (Phase 6 per RESEARCH.md Open Question #1), not a stub. The behavior is specified and tested.

## Self-Check: PASSED

All files found:
- apps/mobile/lib/services/coach/chat_tool_dispatcher.dart — FOUND
- apps/mobile/test/services/coach/chat_tool_dispatcher_test.dart — FOUND
- apps/mobile/test/widgets/coach/widget_renderer_test.dart — FOUND
- apps/mobile/lib/widgets/coach/widget_renderer.dart — FOUND

All commits verified:
- 87b87087 (ChatToolDispatcher) — FOUND
- d7f3e204 (WidgetRenderer route_to_screen) — FOUND
