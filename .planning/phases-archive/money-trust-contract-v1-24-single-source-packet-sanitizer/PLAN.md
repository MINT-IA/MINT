# Phase 24 — Single Source Packet Sanitizer

## Goal

Remove duplicated CoachContextPacket sanitation logic so `/coach/chat`, RAG, and prompt summaries share the same allowlisted contract.

## Problem

`services/backend/app/api/v1/endpoints/coach_chat.py` carried a local copy of the packet allowlists and sanitizer while `services/backend/app/services/coach/context_packet_sanitizer.py` carried the same contract for RAG/profile usage.

This created a drift risk: mobile could emit a valid fact, one backend path could keep it, and another path could silently drop it.

## Scope

- Keep `_sanitize_coach_context_packet` in `coach_chat.py` as a compatibility wrapper.
- Delegate the wrapper to `sanitize_coach_context_packet`.
- Add a direct parity test so future edits cannot reintroduce divergent behavior silently.

## Out of Scope

- No new fact IDs.
- No prompt behavior changes.
- No UI changes.
- No Maestro run; this phase is a backend contract cleanup before broader flow testing.

## Verification Plan

- Compile the endpoint, shared sanitizer, and test file.
- Run packet sanitizer/profile context tests.
- Run budget snapshot and budget absurdity citation gate tests to ensure adjacent trust paths remain green.

