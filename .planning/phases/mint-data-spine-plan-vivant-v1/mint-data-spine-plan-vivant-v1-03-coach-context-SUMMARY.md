---
phase: mint-data-spine-plan-vivant-v1
plan: 03
status: complete
completed_at: 2026-05-23
type: tdd
---

# Plan 03 Summary — Structured Coach Context Packet

## Goal

Create a typed, serializable coach context packet from `DataSpineSnapshot` without wiring chat yet.

## Accomplished

- Added `CoachContextPacket`, `CoachContextFact`, `CoachMissingField`, `CoachTrajectoryContext`, and `CoachNextQuestion`.
- Added `CoachContextPacket.toSafeMap()` for future chat payload serialization.
- Added `CoachContextPacketService.fromSpine()` as a pure `DataSpineSnapshot` mapper.
- Enforced a strict fact allowlist for profile, budget, pillars, and trajectory.
- Added missing-field output for all allowlisted nullable AVS/LPP/3a facts and missing target amount.
- Propagated `PillarFact.state` into serialized facts so known vs estimated remains explicit.
- Added direct synthetic `DataSpineSnapshot` tests so packet mapping is proven from spine values, not only from `CoachProfile`.
- Added Plan 04 anti-facade handoff so the packet must be wired into actual coach/chat paths.

## Verification

- `cd apps/mobile && flutter test test/services/coach_context_packet_service_test.dart` — PASS, 9 tests.
- `cd apps/mobile && flutter test test/services/coach_context_packet_service_test.dart test/services/data_spine_service_test.dart test/services/coach_context_builder_test.dart` — PASS, 27 tests.
- `cd apps/mobile && flutter analyze lib/models/coach_context_packet.dart lib/services/data_spine/coach_context_packet_service.dart` — PASS, no issues.
- `git diff --check` — PASS.

## Explicit Non-Work

- Did not wire the chat payload.
- Did not modify prompts.
- Did not add UI.
- Did not modify persistence or backend.
- Did not expose `firstName`, `commune`, raw wizard maps, employer, address, or NPA.

## Review Disposition

- GSD plan checker: FLAG resolved by adding `toSafeMap()`, source/allowlist tests, explicit Plan 04 integration target, and task-level Action/Verify/Done.
- Architect review: FLAG resolved by removing the age mismatch, adding a strict whitelist, adding no-recompute acceptance criteria, and adding the Plan 04 anti-facade gate.
- QA/code review: FLAG resolved by adding synthetic spine tests, all trajectory branch tests, full nullable pillar missing-field coverage, stricter nested `toSafeMap()` assertions, and serialized pillar fact state.
