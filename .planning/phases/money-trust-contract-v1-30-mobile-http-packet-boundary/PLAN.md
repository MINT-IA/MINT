# Phase 30 — Mobile HTTP Packet Boundary

## Goal

Prove the Flutter server-key coach API sends `coach_context_packet` through the real `/coach/chat` request body without flattening or dropping it, and parses backend `citationChips`.

## Scope

- Add a focused `CoachChatApiService` HTTP contract test.
- Mock auth secure storage and SharedPreferences.
- Capture the actual encoded POST body through `testClient`.
- Assert:
  - `profile_context.coach_context_packet` exists;
  - top-level `coach_context_packet` is not emitted;
  - `persistence_consent` follows `auth_local_mode=false`;
  - `citationChips` parse into `ToolCallCitationChip`.

## Out of Scope

- No production code change.
- No live backend call.
- No Maestro run.
