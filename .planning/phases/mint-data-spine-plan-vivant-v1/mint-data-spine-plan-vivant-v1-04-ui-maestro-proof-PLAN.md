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

# Plan 04 — UI + Maestro Proof Handoff

## Objective

Wire the data spine and `CoachContextPacket` into one visible user flow, then prove it with Maestro.

This placeholder exists now to preserve the anti-facade contract from Plan 03. Full task breakdown will be expanded before execution.

## Mandatory Migration Targets

Plan 04 must inspect and either replace or adapt these current context builders:

- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — current screen-level `_buildCoachContext` path.
- `apps/mobile/lib/services/coach_llm_service.dart` — current LLM context assembly path.
- `apps/mobile/lib/services/coach_narrative_service.dart` — current `_buildProfileContextImpl` path.

## Anti-Facade Gate

Plan 04 must include at least one guard that fails if new coach/chat integration still builds its long-lived context directly from raw `CoachProfile` or raw wizard maps after `CoachContextPacket` adoption.

Acceptable guard forms:

- a unit test proving the chat payload contains `CoachContextPacket.toSafeMap()`;
- a focused grep/lint that blocks new chat context builders bypassing `CoachContextPacket`;
- a Maestro-backed assertion that one visible coach explanation is grounded in packet facts and missing fields after app relaunch.

## Non-Goals

- No broad navigation rewrite.
- No new route unless reuse is impossible.
- No new financial calculation.
