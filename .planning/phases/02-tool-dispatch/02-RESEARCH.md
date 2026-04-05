# Phase 02: Tool Dispatch - Research

**Researched:** 2026-04-05
**Domain:** Flutter coach chat — tool call dispatch pipeline (ParsedToolCall → WidgetRenderer)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Create `ChatToolDispatcher` as a standalone class in `lib/services/coach/chat_tool_dispatcher.dart`. Single entry point that accepts both `ParsedToolCall` (from text markers) and `RagToolCall` (from backend tool_use), normalizes to a common internal type, and dispatches via one switch.
- **D-02:** Keep the `[TOOL_NAME:{json}]` text-marker format for the SLM streaming path. `ChatToolDispatcher` normalizes both formats internally. No backend changes needed.
- **D-03:** Remove the inline `_executeToolCalls` method from `CoachChatScreen`. All dispatch goes through `ChatToolDispatcher`.
- **D-04:** Remove `CoachRichWidgetBuilder` entirely. All widget rendering goes through `ChatToolDispatcher` → `WidgetRenderer`. If the LLM doesn't call a tool, no widget appears. Clean break from keyword matching.
- **D-05:** SLM text-marker tool calls (e.g., `[SHOW_FACT_CARD:{...}]`) are normalized to `RagToolCall` by `ChatToolDispatcher` and added to the message's `richToolCalls` list. Both SLM and BYOK paths produce identical widget rendering via `WidgetRenderer`.
- **D-06:** `route_to_screen` always renders a `RouteSuggestionCard` — the coach PROPOSES, the user DECIDES. No auto-push. Replace the current `context.push(route)` with card rendering.
- **D-07:** `RouteSuggestionCard` passes prefill data from tool call arguments to the target screen via GoRouter extras. This prepares the ground for Phase 6 (Calculator Wiring).
- **D-08:** Unknown tool names are silently ignored. No error shown to user. Debug log only. The message text displays normally without the widget.
- **D-09:** `ToolCallParser.validRoutes` whitelist continues to reject unknown route paths. Behavior for rejected routes at Claude's discretion (silent reject or disabled card).

### Claude's Discretion

- Widget placement relative to message bubble (inline below text vs separate card) — current inline pattern likely best but open to change
- Handling of invalid route paths: silent reject with debug log vs disabled-state RouteSuggestionCard
- Internal `ToolAction` type design (fields, naming)
- Test strategy and granularity

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TDP-01 | Coach tool calls (show_fact_card, show_score_gauge, route_to_screen, etc.) reach the UI and render appropriate widgets | Gap identified: ParsedToolCall objects are parsed but never converted to RagToolCall + placed in richToolCalls. ChatMessage.richToolCalls already exists and WidgetRenderer already renders it. Wire is missing. |
| TDP-02 | ChatToolDispatcher created — parses tool call markers from backend response, dispatches to appropriate UI handler | New class needed: accepts ParsedToolCall + RagToolCall, normalizes, dispatches. Replaces _executeToolCalls in CoachChatScreen. |
| TDP-03 | RoutePlanner suggestions rendered as tappable cards in chat (not just logged "not yet handled") | RouteSuggestionCard fully implemented. Currently _executeToolCalls auto-pushes instead of rendering card. Fix: convert ROUTE_TO_SCREEN marker to route_to_screen RagToolCall, let WidgetRenderer handle it via new route_to_screen case. |
| TDP-04 | CoachRichWidgetBuilder uses LLM tool decisions (not keyword matching fallback) to choose display widgets | CoachRichWidgetBuilder.build() is called at ~line 1450 using userMessage keyword matching. Remove it. Trust richToolCalls from ChatToolDispatcher instead. |
</phase_requirements>

---

## Summary

Phase 2 is a wiring phase. All required components are already built and functional; the pipeline has a missing link between the parser output and the message model. The gap is precisely scoped:

`ToolCallParser.parse()` returns `ParsedToolCall` objects. These are passed to `_executeToolCalls()` in `CoachChatScreen`, which only handles `ROUTE_TO_SCREEN` (and auto-navigates instead of rendering a card). All other tools fall through to a `debugPrint`. Meanwhile, `ChatMessage.richToolCalls: List<RagToolCall>` exists and `CoachMessageBubble` already iterates it and calls `WidgetRenderer.build()` for each — the rendering pipeline is complete and tested.

The fix is to create `ChatToolDispatcher` that converts `ParsedToolCall` → `RagToolCall`, populates `richToolCalls` on the message, and handles `route_to_screen` as a widget (not a navigation call). In parallel, `CoachRichWidgetBuilder` — which triggers widgets based on keyword matching of user messages — is removed entirely. After these changes, both the SLM path (text-marker) and the BYOK path (direct `RagToolCall` from backend) will produce identical widget rendering.

**Primary recommendation:** Create `ChatToolDispatcher` with a single normalization step (ParsedToolCall → RagToolCall), populate `richToolCalls` on ChatMessage at message construction time, add `route_to_screen` case to `WidgetRenderer`, and delete `CoachRichWidgetBuilder` + its call site.

---

## Standard Stack

This phase is purely a Dart/Flutter wiring phase — no new packages needed.

| Component | Version | Purpose | Status |
|-----------|---------|---------|--------|
| `ToolCallParser` | — | Parses `[TOOL_NAME:{json}]` markers from text | Exists, working |
| `WidgetRenderer` | — | Renders 9 tool types from `RagToolCall` | Exists, working |
| `RouteSuggestionCard` | — | Tappable navigation proposal card | Exists, fully implemented |
| `ChatMessage.richToolCalls` | — | Carries `List<RagToolCall>` to bubble | Exists, but never populated from text-marker path |
| `CoachMessageBubble` | — | Renders `richToolCalls` via `WidgetRenderer` | Exists, working |

**No new packages required.** [VERIFIED: codebase grep]

---

## Architecture Patterns

### Current Data Flow (broken)

```
SLM path:
  LLM text → ToolCallParser.parse() → ParsedToolCall list
    → _executeToolCalls() → only ROUTE_TO_SCREEN handled (auto-push)
    → all other tools: debugPrint("not yet handled")

BYOK path:
  Backend RagResponse → ragResponse.toolCalls: List<RagToolCall>
    → CoachOrchestrator converts route_to_screen + generate_document → text markers
    → Same SLM path above

Rendering (parallel, keyword-based):
  CoachRichWidgetBuilder.build(context, userMessage, profile)
    → keyword match on userMessage.toLowerCase()
    → renders widget independently of LLM tool calls
```

### Target Data Flow (after phase)

```
Both paths:
  ParsedToolCall or RagToolCall
    → ChatToolDispatcher.dispatch()
      → normalizes to List<RagToolCall> (ToolAction internally)
      → populates ChatMessage.richToolCalls
      → capped at _maxToolCallsPerResponse (preserve existing logic)

Rendering:
  CoachMessageBubble iterates msg.richToolCalls
    → WidgetRenderer.build(context, toolCall)
      → 9 existing cases + new route_to_screen case
      → returns RouteSuggestionCard for route_to_screen

CoachRichWidgetBuilder: DELETED
```

### Tool Name Normalization Map

The text-marker format uses `SCREAMING_SNAKE_CASE`; `WidgetRenderer` uses `snake_case`. ChatToolDispatcher must normalize:

| Text Marker (ParsedToolCall.toolName) | RagToolCall.name (WidgetRenderer key) |
|---------------------------------------|---------------------------------------|
| `SHOW_FACT_CARD` | `show_fact_card` |
| `SHOW_SCORE_GAUGE` | `show_score_gauge` |
| `SHOW_RETIREMENT_COMPARISON` | `show_retirement_comparison` |
| `SHOW_BUDGET_OVERVIEW` | `show_budget_overview` |
| `SHOW_CHOICE_COMPARISON` | `show_choice_comparison` |
| `SHOW_PILLAR_BREAKDOWN` | `show_pillar_breakdown` |
| `SHOW_BUDGET_SNAPSHOT` | `show_budget_snapshot` |
| `SHOW_COMPARISON_CARD` | `show_comparison_card` |
| `ASK_USER_INPUT` | `ask_user_input` |
| `ROUTE_TO_SCREEN` | `route_to_screen` |
| `GENERATE_DOCUMENT` | `generate_document` (currently not in WidgetRenderer — may stay as text) |

[VERIFIED: codebase grep on WidgetRenderer switch cases and ToolCallParser test fixtures]

### route_to_screen: Widget Renderer Addition

`WidgetRenderer` does not currently have a `route_to_screen` case. This case must be added. The `RouteSuggestionCard` widget is the target. Input map from text-marker path:

```dart
// Text marker produced by CoachOrchestrator (line 638-649):
// {"intent":"retirement_choice","confidence":0.9,"context_message":"..."}
//
// But RouteSuggestionCard requires:
// contextMessage: String (= input['context_message'])
// route: String (resolved from intent OR direct route key)
```

The current `ROUTE_TO_SCREEN` marker passes `route` directly (see `ToolCallParser` tests: `{"route":"/rachat-lpp"}`). But `CoachOrchestrator` passes `intent` + `confidence` + `context_message`. This inconsistency must be handled in `ChatToolDispatcher`:

- If input contains `'route'` key (direct route) → use it
- If input contains `'intent'` key → resolve via `RoutePlanner` (already exists at `lib/services/navigation/route_planner.dart`)

[VERIFIED: codebase read of tool_call_parser_test.dart line 8 vs coach_orchestrator.dart lines 638-649]

### ChatMessage Population Pattern

`ChatMessage` is currently constructed immutably. The `richToolCalls` field is populated at construction time by the BYOK backend path (via `RagResponse.toolCalls`), but NOT by the SLM/text-marker path. The fix requires populating it during message construction in both `_handleSlmStreaming` and `_handleStandardResponse`.

Current SLM path (line 706-714 of coach_chat_screen.dart):
```dart
// Before: setState sets message without richToolCalls, then _executeToolCalls navigates
_messages[...] = ChatMessage(
  role: 'assistant',
  content: finalText,
  // richToolCalls: [] — never set
);
_executeToolCalls(parseResult.toolCalls);

// After: ChatToolDispatcher returns RagToolCall list, message is built with them
final richCalls = ChatToolDispatcher.normalize(parseResult.toolCalls);
_messages[...] = ChatMessage(
  role: 'assistant',
  content: finalText,
  richToolCalls: richCalls,
);
// No _executeToolCalls needed
```

[VERIFIED: codebase read of coach_chat_screen.dart lines 691-719]

### CoachRichWidgetBuilder Removal

`CoachRichWidgetBuilder.build()` is called at line 1450 of `coach_chat_screen.dart` and passed as `richWidget` to `CoachMessageBubble`. In `CoachMessageBubble`, both `richWidget` (keyword-based) and `richToolCalls` (tool-based) are rendered — they can co-exist currently, but after this phase `richWidget` must be removed.

Removal steps:
1. Delete `apps/mobile/lib/widgets/coach/coach_rich_widgets.dart`
2. Remove `import ... coach_rich_widgets.dart` from `coach_chat_screen.dart`
3. Remove `richWidget` local variable computation at line 1448-1452
4. Remove `richWidget:` parameter from `CoachMessageBubble` construction
5. Remove `richWidget` field + rendering from `CoachMessageBubble` itself (line 152-158)

[VERIFIED: codebase read of coach_message_bubble.dart lines 152-158 and coach_chat_screen.dart lines 1447-1452]

### Anti-Patterns to Avoid

- **Auto-push on route_to_screen:** Current `_executeToolCalls` uses `WidgetsBinding.instance.addPostFrameCallback(() => context.push(route))`. This must become a card render, not navigation. D-06 is locked.
- **Constructing ChatMessage after state update:** `richToolCalls` must be in the message at construction time, not patched after `setState`. The bubble renders from the message object.
- **Double rendering:** After removal of `CoachRichWidgetBuilder`, verify the `richWidget` parameter is also removed from `CoachMessageBubble`'s constructor and build method. Leaving a null `richWidget` parameter is fine short-term but should be cleaned up.
- **Forgetting the cap:** `_maxToolCallsPerResponse = 5` cap logic in `_executeToolCalls` must be preserved in `ChatToolDispatcher`. [VERIFIED: coach_chat_screen.dart line 830]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tool name normalization | Custom regex or string manipulation | Simple `.toLowerCase()` on ParsedToolCall.toolName — the screaming snake matches exactly when lowercased | One-line conversion; already verified in test fixtures |
| Route resolution from intent | New intent→route mapping | Existing `RoutePlanner` at `lib/services/navigation/route_planner.dart` | Already maps intents to RouteDecision (used by coach_chat_test.dart) |
| Card rendering | Custom widget | `RouteSuggestionCard` — already handles prefill, warning banners, ReturnContract V2, entrance animation | Fully production-grade |
| Widget dispatch registry | Map<String, WidgetBuilder> pattern | `WidgetRenderer.build()` switch statement — already exists for 9 types | Adding `route_to_screen` case is a 10-line addition |

---

## Common Pitfalls

### Pitfall 1: Intent-vs-Route key mismatch
**What goes wrong:** `ChatToolDispatcher` tries to read `input['route']` on a BYOK tool call that carries `input['intent']` (from `CoachOrchestrator`), gets null, silently skips the card.
**Why it happens:** Text-marker tests use `route` key directly; `CoachOrchestrator` converts to `intent` + `confidence` + `context_message`.
**How to avoid:** In `ChatToolDispatcher`, check for both keys: `input['route'] ?? RoutePlanner.resolve(input['intent'])?.route`.
**Warning signs:** `RouteSuggestionCard` never appears on BYOK path; appears on SLM path. Test both paths.

### Pitfall 2: richToolCalls populated after setState
**What goes wrong:** Message is created without `richToolCalls`, `setState` triggers a rebuild, then `richToolCalls` are added in a second `setState`. The bubble renders once without widgets, then flickers.
**Why it happens:** Developer separates normalization from message construction.
**How to avoid:** Normalize tool calls BEFORE constructing `ChatMessage`, pass them in `richToolCalls:` at construction.

### Pitfall 3: CoachMessageBubble still has richWidget parameter
**What goes wrong:** After deleting `CoachRichWidgetBuilder`, `richWidget` is passed as `null` from `CoachChatScreen`. The bubble still has the old rendering path for `richWidget` — harmless but dead code and confusing.
**How to avoid:** Remove the `richWidget` field from `CoachMessageBubble` in the same PR as `CoachRichWidgetBuilder` deletion.

### Pitfall 4: Missing route_to_screen in WidgetRenderer
**What goes wrong:** `ChatToolDispatcher` normalizes `ROUTE_TO_SCREEN` to a `RagToolCall(name: 'route_to_screen', ...)`. `WidgetRenderer.build()` hits the `default: return null` case. No widget appears.
**Why it happens:** `WidgetRenderer` has 9 cases — none is `route_to_screen`. It handles BYOK display tools, not navigation tools.
**How to avoid:** Add `case 'route_to_screen':` to `WidgetRenderer.build()` that returns a `RouteSuggestionCard`.
**Warning signs:** TDP-03 test fails; `RouteSuggestionCard` never appears. Use `debugPrint` in default case during development.

### Pitfall 5: Tool call cap lost in refactor
**What goes wrong:** `ChatToolDispatcher.normalize()` returns the full list without capping. A malformed LLM response with 20 tool calls floods the message bubble.
**Why it happens:** Cap logic lives in `_executeToolCalls` (to be deleted) and is not carried to the new class.
**How to avoid:** `ChatToolDispatcher` must apply `_maxToolCallsPerResponse = 5` cap before returning.

---

## Code Examples

### ChatToolDispatcher Skeleton

```dart
// Source: derived from existing _executeToolCalls (coach_chat_screen.dart:832)
// and ToolCallParser + RagToolCall (verified)

class ChatToolDispatcher {
  static const _maxToolCallsPerResponse = 5;

  /// Normalize ParsedToolCall list (text-marker path) to RagToolCall list.
  /// Returns at most [_maxToolCallsPerResponse] entries.
  static List<RagToolCall> normalize(List<ParsedToolCall> parsed) {
    final capped = parsed.take(_maxToolCallsPerResponse).toList();
    if (parsed.length > _maxToolCallsPerResponse) {
      debugPrint('[ChatToolDispatcher] capped ${parsed.length} → $_maxToolCallsPerResponse');
    }
    return capped
        .map((p) => RagToolCall(
              name: p.toolName.toLowerCase(), // SHOW_FACT_CARD → show_fact_card
              input: p.arguments,
            ))
        .toList();
  }

  /// Filter a RagToolCall list (BYOK path) to at most [_maxToolCallsPerResponse].
  static List<RagToolCall> filterRag(List<RagToolCall> calls) {
    if (calls.length <= _maxToolCallsPerResponse) return calls;
    debugPrint('[ChatToolDispatcher] capped ${calls.length} → $_maxToolCallsPerResponse');
    return calls.take(_maxToolCallsPerResponse).toList();
  }

  /// Validate a route_to_screen tool call.
  /// Returns the resolved route string, or null if route is invalid/unknown.
  static String? resolveRoute(Map<String, dynamic> input) {
    final direct = input['route'] as String?;
    if (direct != null) {
      return ToolCallParser.isValidRoute(direct) ? direct : null;
    }
    // intent-based (BYOK path from CoachOrchestrator)
    // RoutePlanner.resolve() returns a RouteDecision with a route field.
    // Kept at Claude's discretion; stub here for reference.
    return null;
  }
}
```

### WidgetRenderer route_to_screen case

```dart
// Add to WidgetRenderer.build() switch (after 'ask_user_input' case):
case 'route_to_screen':
  return _buildRouteSuggestion(context, call.input);

static Widget _buildRouteSuggestion(
    BuildContext context, Map<String, dynamic> p) {
  final route = p['route'] as String? ?? '';
  final contextMessage = p['context_message'] as String?
      ?? p['narrative'] as String?
      ?? '';
  final prefill = p['prefill'] as Map<String, dynamic>?;
  if (!ToolCallParser.isValidRoute(route)) return const SizedBox.shrink();
  return RouteSuggestionCard(
    contextMessage: contextMessage,
    route: route,
    prefill: prefill,
    isPartial: p['is_partial'] as bool? ?? false,
  );
}
```

### SLM path: message construction with richToolCalls

```dart
// In _handleSlmStreaming, replace:
//   _executeToolCalls(parseResult.toolCalls);
// With (richToolCalls already in message):

final richCalls = ChatToolDispatcher.normalize(parseResult.toolCalls);
setState(() {
  _messages[_messages.length - 1] = ChatMessage(
    role: 'assistant',
    content: finalText,
    timestamp: DateTime.now(),
    suggestedActions: suggestedActions,
    responseCards: cards,
    tier: ChatTier.slm,
    richToolCalls: richCalls,  // <-- was always empty before
  );
  _isStreaming = false;
});
```

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | `apps/mobile/pubspec.yaml` dev_dependencies |
| Quick run command | `flutter test test/services/tool_call_parser_test.dart test/widgets/coach/ -x` |
| Full suite command | `flutter test` (8137 tests) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TDP-01 | show_fact_card ParsedToolCall → RagToolCall → widget rendered | unit | `flutter test test/services/chat_tool_dispatcher_test.dart` | Wave 0 |
| TDP-02 | ChatToolDispatcher.normalize() caps at 5, lowercases names | unit | `flutter test test/services/chat_tool_dispatcher_test.dart` | Wave 0 |
| TDP-03 | route_to_screen → RouteSuggestionCard in bubble (not auto-push) | widget | `flutter test test/screens/coach/coach_chat_test.dart` | Exists (extend) |
| TDP-04 | Message with richToolCalls renders widget; same message without richToolCalls renders no keyword widget | widget | `flutter test test/widgets/coach/coach_message_bubble_test.dart` | Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/services/chat_tool_dispatcher_test.dart test/services/tool_call_parser_test.dart`
- **Per wave merge:** `flutter test test/services/ test/widgets/coach/ test/screens/coach/`
- **Phase gate:** `flutter test && flutter analyze` — full suite green, 0 analysis issues

### Wave 0 Gaps

- [ ] `test/services/chat_tool_dispatcher_test.dart` — covers TDP-01, TDP-02 (normalization, cap, name lowercasing, route validation)
- [ ] `test/widgets/coach/coach_message_bubble_test.dart` — covers TDP-04 (richToolCalls renders FactCard; no richToolCalls renders nothing)
- [ ] Update `test/screens/coach/coach_chat_test.dart` — add test: route_to_screen tool call produces RouteSuggestionCard (TDP-03)

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | `ToolCallParser.validRoutes` whitelist rejects arbitrary routes; JSON parse errors silently skip tool calls |
| V6 Cryptography | no | — |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| LLM prompt injection producing malicious route (`javascript:alert(1)`, `/admin/delete`) | Tampering | `ToolCallParser.isValidRoute()` whitelist — 68 known-good routes; anything else is rejected |
| LLM producing >100 tool calls (flooding) | DoS | `_maxToolCallsPerResponse = 5` cap in `ChatToolDispatcher` |
| LLM producing tool call with nested JSON containing script in string | Tampering | Flutter widget rendering treats all strings as text, not HTML — no XSS vector |

[VERIFIED: codebase read of ToolCallParser.validRoutes whitelist + _maxToolCallsPerResponse]

---

## Environment Availability

Step 2.6: SKIPPED — this phase is purely Flutter/Dart code changes with no external service dependencies. No new packages, no external APIs, no CLI tools beyond the existing Flutter SDK.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Keyword matching on user message | LLM tool calls decide widgets | This phase | Widgets appear only when LLM explicitly calls a tool — no false positives, no missed triggers |
| Auto-push navigation on route_to_screen | RouteSuggestionCard proposal | D-06 (locked) | User decides navigation; coach proposes |

---

## Open Questions

1. **RoutePlanner.resolve() signature for intent-based route resolution**
   - What we know: `RoutePlanner` exists at `lib/services/navigation/route_planner.dart`, imported in `coach_chat_test.dart`
   - What's unclear: Whether it accepts a raw intent string and returns a route string, or requires a `CoachProfile` context
   - Recommendation: Read `route_planner.dart` at plan/implementation time. If complex, use the direct `route` key path only (D-09: behavior for rejected routes at Claude's discretion) and defer intent resolution to Phase 6.

2. **generate_document tool call handling**
   - What we know: `CoachOrchestrator` converts `generate_document` to `[GENERATE_DOCUMENT:{...}]` marker; `ChatToolDispatcher` will normalize it to `RagToolCall(name: 'generate_document', ...)`
   - What's unclear: Whether `WidgetRenderer` should handle `generate_document` in this phase, or whether it should fall through to `default: null` silently (existing behavior)
   - Recommendation: D-08 covers this — unknown tool names silently ignored. `generate_document` rendering is out of scope for Phase 2.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `SCREAMING_SNAKE_CASE.toLowerCase()` = snake_case for all 9 WidgetRenderer tool names | Architecture Patterns — normalization map | Low: verified against WidgetRenderer switch cases and test fixtures; any discrepancy caught by TDP-01 test |
| A2 | `RoutePlanner` can resolve an intent string to a route without requiring BuildContext | Open Questions #1 | Medium: if RoutePlanner requires BuildContext or async resolution, `ChatToolDispatcher` may need to defer or simplify |

---

## Sources

### Primary (HIGH confidence)
- `apps/mobile/lib/services/coach/tool_call_parser.dart` — ParsedToolCall type, validRoutes whitelist, parse() behavior
- `apps/mobile/lib/widgets/coach/widget_renderer.dart` — 9 tool types, switch structure, RagToolCall input map keys
- `apps/mobile/lib/widgets/coach/coach_rich_widgets.dart` — keyword matching pattern TO BE REMOVED
- `apps/mobile/lib/widgets/coach/route_suggestion_card.dart` — constructor signature, prefill, ReturnContract V2
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — _executeToolCalls (lines 832-862), _handleSlmStreaming (691-726), _handleStandardResponse (728-817), CoachRichWidgetBuilder.build call (line 1450)
- `apps/mobile/lib/widgets/coach/coach_message_bubble.dart` — richToolCalls rendering (lines 110-127), richWidget rendering (lines 152-158)
- `apps/mobile/lib/services/coach_llm_service.dart` — ChatMessage model, richToolCalls field, RagToolCall import
- `apps/mobile/lib/services/rag_service.dart` — RagToolCall class definition
- `apps/mobile/lib/services/coach/coach_orchestrator.dart` — tool_use → text-marker conversion (lines 637-650)
- `apps/mobile/test/services/tool_call_parser_test.dart` — verified text-marker format and valid route whitelist

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components verified by direct codebase read
- Architecture: HIGH — data flow traced line by line through all integration points
- Pitfalls: HIGH — each pitfall derived from actual code state, not speculation
- Open questions: MEDIUM — RoutePlanner internals not yet read (deferred to plan/impl)

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (stable domain — no package updates needed)
