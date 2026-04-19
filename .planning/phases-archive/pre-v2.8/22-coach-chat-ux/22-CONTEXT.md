# Phase 22: Coach Chat UX - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning
**Mode:** Auto-generated from Gate 0 findings

<domain>
## Phase Boundary

Fix 4 UX bugs in the coach chat screen:
1. Markdown not rendering — literal `**asterisks**` visible in coach responses (P0-4)
2. Keyboard stays up after sending message — must scroll to read response
3. Coach responses too long — walls of text, needs chunking or progressive disclosure
4. Source/disclaimer blocks too verbose — paragraph after every message, should be 1-line expandable

Requirements: UX-01, UX-02, UX-03, UX-05

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All choices at Claude's discretion — these are UX fixes to the coach chat screen.

Key files:
- apps/mobile/lib/screens/coach/coach_chat_screen.dart — the main chat screen
- apps/mobile/lib/widgets/coach/ — chat bubble widgets, message rendering
- pubspec.yaml — check if flutter_markdown is already a dependency

Fix approaches:
- UX-01: Use flutter_markdown or flutter_markdown_selectable for coach message rendering
- UX-02: Call FocusScope.of(context).unfocus() on send, then scroll to bottom
- UX-03: System prompt directive to limit response length, OR client-side truncation with "Lire la suite"
- UX-05: Wrap disclaimer in ExpansionTile or similar — collapsed by default, 1-line summary

</decisions>

<code_context>
## Existing Code Insights

Codebase context gathered during planning.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — fix the 4 bugs.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
