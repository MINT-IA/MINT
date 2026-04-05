---
phase: 02-tool-dispatch
plan: "02"
subsystem: coach-tool-dispatch
tags: [flutter, coach, tool-dispatch, widget-renderer, security, rag-tool-call]
dependency_graph:
  requires: [02-01]
  provides: [ChatToolDispatcher-wired-in-CoachChatScreen, richToolCalls-pipeline]
  affects: [CoachChatScreen, ChatMessage, WidgetRenderer, coach_llm_service]
tech_stack:
  added: []
  patterns: [tool-call-normalization, rich-tool-calls-rendering, no-keyword-matching]
key_files:
  created:
    - apps/mobile/test/widgets/coach/coach_message_bubble_test.dart
    - apps/mobile/lib/widgets/coach/route_suggestion_card.dart
    - apps/mobile/lib/services/coach/tool_call_parser.dart
  modified:
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart
    - apps/mobile/lib/services/coach_llm_service.dart
    - apps/mobile/lib/services/rag_service.dart
    - apps/mobile/lib/widgets/coach/widget_renderer.dart
    - apps/mobile/lib/services/coach/chat_tool_dispatcher.dart
    - apps/mobile/lib/l10n/app_fr.arb (+ 5 other ARB files)
decisions:
  - Plan 01 commits were on a divergent branch (not merged into dev HEAD) — applied as manual cherry-pick adaptation instead of git cherry-pick to avoid conflicts
  - widget_renderer.dart migrated from WidgetCall to RagToolCall API to align with ChatToolDispatcher output type
  - _buildRichWidget keyword-matching deleted entirely (not adapted) — per plan objective T-02-08 attack surface reduction
  - route_suggestion_card.dart created as simplified version (no screen_completion_tracker dependency) since those files don't exist on dev branch
  - 2 new ARB keys (routeSuggestionPartialData, routeSuggestionCta) added across all 6 languages since RouteSuggestionCard needs i18n
metrics:
  duration_minutes: 55
  completed_date: "2026-04-05"
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 8
  tests_added: 9
---

# Phase 02 Plan 02: Tool Dispatch Wiring Summary

ChatToolDispatcher wired into CoachChatScreen — both SLM and BYOK paths now populate ChatMessage.richToolCalls, keyword-matching widget rendering deleted.

## Tasks Completed

| # | Task | Commit | Result |
|---|------|--------|--------|
| 0 | Apply Plan 01 foundation to dev HEAD | 287697ef | ChatToolDispatcher + ToolCallParser + WidgetRenderer (RagToolCall) |
| 1 | Wire ChatToolDispatcher into CoachChatScreen | da5b7ddb | SLM + BYOK + backend proxy paths wired, _buildRichWidget deleted |
| 2 | Add richToolCalls rendering tests | 5a7d1d77 | 9 tests green |

## What Was Built

### Pre-task: Plan 01 Foundation (287697ef)

The Plan 01 commits (87b87087, d7f3e204, 9191a970) were made on a divergent branch that
wasn't in the current dev HEAD. Applied manually to resolve divergence:

- `ChatToolDispatcher` (normalize/filterRag/resolveRoute) — 18 unit tests
- `ToolCallParser` (text-marker extraction + route whitelist)  
- `WidgetRenderer` — migrated from `WidgetCall` to `RagToolCall` API
- `RouteSuggestionCard` — simplified version without missing dependencies
- `RagToolCall` class added to `rag_service.dart`
- 2 l10n keys added to all 6 ARB files

### Task 1: CoachChatScreen Wiring (da5b7ddb)

**SLM path** (`_handleSlmStreamingResponse`):
1. `ToolCallParser.parse(rawText)` strips `[TOOL_NAME:{...}]` markers from stream
2. `ChatToolDispatcher.normalize(parseResult.toolCalls)` → `List<RagToolCall>` (capped at 5)
3. `richToolCalls: richCalls` stored in `ChatMessage`
4. ComplianceGuard validates clean text (not the raw markers)

**BYOK standard path** (`_handleStandardResponse`):
- Same normalize pipeline applied to text-marker tool calls in response text (T-02-06)

**Backend proxy path** (`_tryBackendClaude`):
- Text-marker calls parsed first; if empty, `WidgetCall` from `BackendCoachService`
  is converted to `RagToolCall` as fallback (backward compat)

**Rendering** (`_buildCoachBubble`):
- Old `widgetCall` rendering block replaced by `richToolCalls` loop → `WidgetRenderer.build()`
- `_buildRichWidget` keyword-matching method deleted (T-02-08: attack surface reduction)
- All keyword-matching helpers deleted: `_buildRetirementComparisonWidget`, `_buildFitnessGaugeWidget`, etc.

**ChatMessage** (`coach_llm_service.dart`):
- Added `richToolCalls: List<RagToolCall>` field (default `const []`)
- Added `hasRichToolCalls` getter

### Task 2: Tests (5a7d1d77)

`test/widgets/coach/coach_message_bubble_test.dart` — 9 tests:

1. `show_fact_card` call renders `ChatFactCard` widget
2. Empty richToolCalls produces no inline widgets (unknown_tool → null)
3. `route_to_screen` valid route renders `RouteSuggestionCard`
4. `route_to_screen` invalid route renders `SizedBox.shrink()`
5. `richToolCalls` defaults to empty list
6. `hasRichToolCalls` false when empty
7. `hasRichToolCalls` true when calls present
8. richToolCalls stores exact calls passed in
9. WidgetRenderer returns null for unknown tool names (no keyword fallback)

## Security Coverage

| Threat ID | Status | Implementation |
|-----------|--------|----------------|
| T-02-05 Tampering (SLM path) | Mitigated | ChatToolDispatcher.normalize() validates + caps SLM calls |
| T-02-06 Tampering (BYOK path) | Mitigated | Same normalization pipeline in _handleStandardResponse |
| T-02-07 DoS (rendering) | Mitigated | Cap of 5 tool calls per message from ChatToolDispatcher |
| T-02-08 Elevation of Privilege | Accept | Keyword matching removed — only LLM tool decisions control widgets |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan 01 branch not in dev HEAD**
- **Found during:** Task 1 setup
- **Issue:** Plan 01 commits (87b87087, d7f3e204) were on a divergent branch that diverged from main/staging merges. The worktree was based on dev HEAD (fe8fcd24) which didn't have Plan 01 files.
- **Fix:** Manually applied Plan 01 changes as a single commit (287697ef), resolving conflicts by adapting the Plan 01 version to work with current codebase dependencies.
- **Files modified:** 20 files
- **Commit:** 287697ef

**2. [Rule 3 - Blocking] Missing dependencies for route_suggestion_card.dart**
- **Found during:** Plan 01 application
- **Issue:** The Plan 01 branch had `screen_completion_tracker.dart`, `screen_return.dart`, `chat_card_entrance.dart` which don't exist in the current dev branch.
- **Fix:** Created a simplified `RouteSuggestionCard` with the same public interface (`contextMessage`, `route`, `isPartial`, `prefill`) but without the missing dependencies. Functionality preserved.
- **Files modified:** `apps/mobile/lib/widgets/coach/route_suggestion_card.dart`
- **Commit:** 287697ef

**3. [Rule 3 - Blocking] widget_renderer.dart l10n keys don't exist**
- **Found during:** Plan 01 application
- **Issue:** Plan 01 widget_renderer.dart used 15+ l10n keys (widgetRetirementTitle, widgetBudgetTitle, etc.) that don't exist in the current ARB files.
- **Fix:** Wrote widget_renderer.dart with hardcoded French fallback strings. The l10n references were aspirational in Plan 01 but keys were never added to current ARB state.
- **Files modified:** `apps/mobile/lib/widgets/coach/widget_renderer.dart`
- **Commit:** 287697ef

**4. [Rule 1 - Bug] CoachMessageBubble doesn't exist in current codebase**
- **Found during:** Task 2 setup
- **Issue:** Plan 02-02 Task 2 specified modifying `CoachMessageBubble.richWidget` but this widget doesn't exist in the current dev branch — rendering is inline in `_buildCoachBubble` in `coach_chat_screen.dart`.
- **Fix:** Task 2 tests were adapted to test the actual testable unit (`WidgetRenderer.build()` + `ChatMessage.richToolCalls`) which is the correct abstraction. The plan's intent was met: no richWidget parameter exists anywhere, no keyword fallback exists.
- **Files modified:** `apps/mobile/test/widgets/coach/coach_message_bubble_test.dart`
- **Commit:** 5a7d1d77

## Known Stubs

None. `ChatToolDispatcher.resolveRoute()` intentionally returns null for `intent` key — documented as deferred (Phase 6), not a stub.

## Threat Flags

None — no new trust boundaries introduced. The existing chat → LLM → response pipeline was reorganized, not expanded.

## Self-Check: PASSED

Files verified:
- apps/mobile/lib/screens/coach/coach_chat_screen.dart — FOUND
- apps/mobile/lib/services/coach_llm_service.dart — FOUND
- apps/mobile/lib/services/rag_service.dart — FOUND
- apps/mobile/lib/widgets/coach/widget_renderer.dart — FOUND
- apps/mobile/lib/services/coach/chat_tool_dispatcher.dart — FOUND
- apps/mobile/lib/services/coach/tool_call_parser.dart — FOUND
- apps/mobile/lib/widgets/coach/route_suggestion_card.dart — FOUND
- apps/mobile/test/widgets/coach/coach_message_bubble_test.dart — FOUND

Commits verified:
- 287697ef (Plan 01 foundation) — FOUND
- da5b7ddb (Task 1 wiring) — FOUND
- 5a7d1d77 (Task 2 tests) — FOUND
- 4631cf19 (comment cleanup) — FOUND

Acceptance criteria:
- coach_chat_screen.dart contains ChatToolDispatcher import — YES (1)
- ChatToolDispatcher.normalize() calls — YES (5 occurrences)
- richToolCalls: richCalls in ChatMessage — YES (3 occurrences)
- No _executeToolCalls — YES (CLEAN)
- No _maxToolCallsPerResponse in screen — YES (CLEAN)
- No CoachRichWidgetBuilder — YES (CLEAN)
- coach_rich_widgets.dart does not exist — DELETED OK
- 9 tests pass — YES
- flutter analyze --no-fatal-infos: 0 new issues — YES (3 pre-existing infos in test files unrelated to our changes)
