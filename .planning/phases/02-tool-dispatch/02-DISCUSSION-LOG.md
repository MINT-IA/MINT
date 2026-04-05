# Phase 2: Tool Dispatch - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-05
**Phase:** 02-tool-dispatch
**Areas discussed:** Dispatch architecture, Widget rendering strategy, Route suggestion UX, Fallback & error handling

---

## Dispatch Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Single entry point | ChatToolDispatcher accepts both ParsedToolCall and RagToolCall, normalizes to common ToolAction type, dispatches via one switch | ✓ |
| Keep paths separate, shared handlers | ToolCallParser stays for text markers, WidgetRenderer stays for structured calls. ChatToolDispatcher delegates based on source | |
| You decide | Claude picks during planning | |

**User's choice:** Single entry point
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Standalone class | Own file in services/coach/. Testable in isolation. Matches TDP-04 'distinct class' requirement. | ✓ |
| Mixin on _CoachChatScreenState | Keeps dispatch logic co-located with UI. Harder to test. | |

**User's choice:** Standalone class
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Keep text markers for SLM | SLM streaming produces text chunks — markers are natural. ChatToolDispatcher normalizes both formats. No backend change. | ✓ |
| Move SLM to structured output | Requires SLM to buffer and emit structured JSON blocks. Needs backend changes. | |

**User's choice:** Keep text markers for SLM
**Notes:** None

---

## Widget Rendering Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Remove entirely | All rendering through ChatToolDispatcher → WidgetRenderer. If LLM doesn't call tool, no widget. SC-3 tests this. | ✓ |
| Keep as silent fallback | WidgetRenderer primary, CoachRichWidgetBuilder as degraded mode. Contradicts SC-3. | |
| You decide | Claude picks during planning | |

**User's choice:** Remove entirely
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Inline below message text | Widgets render inside CoachMessageBubble, after the text. Current pattern. | |
| Separate card outside bubble | Widget renders as distinct chat item below bubble. | |
| You decide | Claude picks best layout during planning | ✓ |

**User's choice:** You decide
**Notes:** None

---

## Route Suggestion UX

| Option | Description | Selected |
|--------|-------------|----------|
| RouteSuggestionCard always | Coach proposes, user decides. Matches MINT UX principle. SC-2 requires 'tapping it navigates'. | ✓ |
| Auto-push for high confidence, card for partial | Two behaviors depending on data readiness. | |
| You decide | Claude picks during planning | |

**User's choice:** RouteSuggestionCard always
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, via GoRouter extras | Tool call includes prefill fields. RouteSuggestionCard passes via GoRouter extra. Sets up Phase 6. | ✓ |
| No prefill in Phase 2 | Phase 2 just wires the card. Prefill is Phase 6's job. | |

**User's choice:** Yes, via GoRouter extras
**Notes:** None

---

## Fallback & Error Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Silent skip | Unknown tool names silently ignored. Debug log only. Message text displays normally. | ✓ |
| Show subtle error card | Render muted card saying 'Widget indisponible'. | |
| You decide | Claude picks during planning | |

**User's choice:** Silent skip
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, normalize to RagToolCall | ChatToolDispatcher converts ParsedToolCall to RagToolCall, adds to richToolCalls. Both paths produce identical widgets. | ✓ |
| No, SLM stays text-only | Only BYOK/RAG path gets rich widgets. Two-tier experience. | |

**User's choice:** Yes, normalize to RagToolCall
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Silently reject with debug log | Current behavior. ToolCallParser.validRoutes whitelist rejects unknown routes. | |
| Show card with disabled state | Render RouteSuggestionCard with disabled CTA and 'Route indisponible' message. | |

**User's choice:** "Je te laisse décider car je ne suis pas sûr." — deferred to Claude's discretion
**Notes:** None

---

## Claude's Discretion

- Widget placement relative to message bubble (inline vs separate card)
- Invalid route path handling (silent reject vs disabled card)
- Internal ToolAction type design
- Test strategy and granularity

## Deferred Ideas

None — discussion stayed within phase scope
