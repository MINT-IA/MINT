# Phase 29 — Summary

## Changed

- Added two endpoint-level citation tests in `TestCoachChatCitationGate`.
- Fixed `_run_narrator_with_gate` so tool-use enforcement checks raw narrator text before `{{cite:tool_*}}` placeholders are substituted.
- If a retry passes citation-gate but lacks the matching tool call, the endpoint now returns `FALLBACK_TEMPLATED_TEXT` and strips tool calls/chips.

## Result

The coach can repair an uncited absurd answer with a proper tool-cited answer, but cannot cite a tool without actually using it.
