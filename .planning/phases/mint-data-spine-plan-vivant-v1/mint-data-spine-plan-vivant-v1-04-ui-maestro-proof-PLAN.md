---
phase: mint-data-spine-plan-vivant-v1
plan: 04
type: integration
wave: 4
depends_on:
  - mint-data-spine-plan-vivant-v1-03-coach-context-PLAN.md
files_modified:
  - apps/mobile/lib/screens/coach/coach_chat_screen.dart
  - apps/mobile/lib/services/coach_llm_service.dart
  - apps/mobile/lib/services/coach_narrative_service.dart
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/app/schemas/rag.py
  - tools/simulator/flows/maestro-perfect-set/
autonomous: false
requirements:
  - REQ-DSP-05
must_haves:
  truths:
    - "Plan 04 must wire CoachContextPacket into the actual chat/UI path."
    - "Plan 04 must not leave CoachContextPacket as a tested but unused facade."
    - "Existing raw CoachProfile context builders must be replaced, adapted, or explicitly scoped as legacy-only with a failing guard for new chat paths."
---

# Plan 04 — Coach Packet Wiring + UI Proof

## Objective

Wire the data spine and `CoachContextPacket` into the real coach/chat path,
then prove with tests that chat payloads can no longer bypass or lose the
packet at the backend boundary.

This plan deliberately keeps the first cut narrow: make the structured packet
available to the existing orchestrator/backend context path without rewriting
navigation or chat UI.

## Mandatory Migration Targets

Plan 04 must inspect and either replace or adapt these current context builders:

- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — current screen-level `_buildCoachContext` path.
- `apps/mobile/lib/services/coach_llm_service.dart` — current LLM context assembly path.
- `apps/mobile/lib/services/coach_narrative_service.dart` — current `_buildProfileContextImpl` path.

## Implementation Strategy

Use `CoachContext` as the adapter seam because it is already the object passed
from the screen/service builders into:

- `CoachOrchestrator.streamChat`
- `CoachOrchestrator.generateChat`
- BYOK `/rag/query`
- server-key `/coach/chat`
- `ComplianceGuard`

Plan 04 adds a `coachContextPacket` safe-map field to `CoachContext`, computes
it from `DataSpineService.fromProfile(profile)` + `CoachContextPacketService`,
and injects it into backend `profile_context` under a single canonical key:
`coach_context_packet`. The backend must explicitly whitelist and type this
field; otherwise this plan is a facade because `_sanitize_profile_context` and
RAG `ProfileContext` drop unknown keys.

## Tasks

### Task 1 — TDD: payload guard

Action:
- Add a focused unit test proving a `CoachContext` carrying a packet serializes
  into the backend profile context with `coach_context_packet`.
- Assert the packet contains `facts`, `missing_fields`, `trajectory`, and
  `next_questions`.
- Assert raw PII/raw profile keys such as `first_name`, `commune`, and
  `wizard_answers` are absent from the packet.

Verify:
- `cd apps/mobile && flutter test test/services/coach_context_packet_payload_test.dart`

Done:
- The test fails before implementation and passes after the orchestrator helper
  is wired.

### Task 2 — Wire packet into builders

Action:
- Extend `CoachContext` and `CoachContextBuilder` with an optional
  `coachContextPacket`.
- In `CoachChatScreen._buildCoachContext`, derive the packet from
  `DataSpineSnapshot` and attach `packet.toSafeMap()`.
- In `CoachLlmService._buildCoachContext`, do the same for non-screen callers.

Verify:
- Existing coach context tests still pass.
- No new persistence path is introduced.

Done:
- The real chat path receives the packet before any BYOK/server-key dispatch.

### Task 3 — Unify backend profile_context assembly

Action:
- Factor duplicated profile-context map assembly in `CoachOrchestrator` into
  one helper.
- Include `coach_context_packet` only when present.
- Keep legacy scalar fields for compatibility, but treat the packet as the new
  structured context spine.

Verify:
- Unit guard passes.
- `rg "coach_context_packet|CoachContextPacket" apps/mobile/lib apps/mobile/test`
  shows the packet is wired into the actual chat/orchestrator path.

Done:
- BYOK and server-key payloads share the same packet injection.

### Task 4 — Narrative legacy scoping

Action:
- Do not rewrite `CoachNarrativeService._buildProfileContextImpl` in this plan.
- Add an explicit comment/test note that it remains a legacy RAG/narrative
  profile-context surface until a follow-up migration, while chat now uses
  `CoachContextPacket`.

Verify:
- Existing `coach_narrative_profile_context_test.dart` remains green.

Done:
- No ambiguous fourth context builder is added.

### Task 5 — Backend survival guard

Action:
- Add `coach_context_packet` to backend `/coach/chat` safe fields.
- Sanitize nested packet strings recursively for injection markers.
- Add `coach_context_packet` to RAG `ProfileContext`.
- Add backend tests proving the packet survives sanitization and is wired into
  `CoachContext`.

Verify:
- `cd services/backend && pytest -q tests/coach/test_coach_chat_profile_sanitize_context_packet.py`

Done:
- Mobile packet cannot be silently dropped by backend profile-context filters.

### Task 6 — Local verification and GSD close-out

Action:
- Run focused tests and analyzer on touched files.
- Update this plan and add a summary with results.
- Request code/QA review after implementation.

Verify:
- `cd apps/mobile && flutter test test/services/coach_context_packet_payload_test.dart test/services/coach_context_packet_service_test.dart test/services/coach_chat_api_service_safe_mode_payload_test.dart test/services/coach_narrative_profile_context_test.dart`
- `cd apps/mobile && flutter analyze lib/services/coach/coach_models.dart lib/services/coach/coach_context_builder.dart lib/services/coach/coach_orchestrator.dart lib/services/coach_llm_service.dart lib/screens/coach/coach_chat_screen.dart`
- `cd services/backend && pytest -q tests/coach/test_coach_chat_profile_sanitize_context_packet.py`
- `git diff --check`

Done:
- GSD summary records what was wired, what remains, and whether Maestro is still
  pending.

## Anti-Facade Gate

Plan 04 must include at least one guard that fails if new coach/chat integration still builds its long-lived context directly from raw `CoachProfile` or raw wizard maps after `CoachContextPacket` adoption.

Acceptable guard forms:

- a unit test proving the chat payload contains `CoachContextPacket.toSafeMap()`;
- a focused grep/lint that blocks new chat context builders bypassing `CoachContextPacket`;
- a Maestro-backed assertion that one visible coach explanation is grounded in packet facts and missing fields after app relaunch.

Selected gate for this plan:

- Unit guard proving the orchestrator profile payload contains
  `CoachContextPacket.toSafeMap()` under `coach_context_packet`.
- Grep proof that `coach_context_packet` is present in the live orchestrator
  dispatch path.
- Backend guard proving `_sanitize_profile_context` and `ProfileContext` do not
  drop `coach_context_packet`.

Maestro remains the follow-up proof once a visible packet-backed response/card
is introduced.

## Non-Goals

- No broad navigation rewrite.
- No new route unless reuse is impossible.
- No new financial calculation.
- No attempt to make the SLM quote the packet visually before the payload path
  is stable.
