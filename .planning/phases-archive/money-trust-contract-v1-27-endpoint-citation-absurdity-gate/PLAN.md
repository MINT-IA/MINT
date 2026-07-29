# Phase 27 — Endpoint Citation Absurdity Gate

## Goal

Prove the real `/coach/chat` endpoint blocks absurd uncited CHF amounts before they reach the mobile user.

## Problem

Phase 22 covered the citation parser directly. That was necessary but not sufficient: a parser unit test does not prove the endpoint wrapper, retry-once flow, and response builder protect the user-facing message.

## Scope

- Patch `_run_agent_loop` in the endpoint test to emit absurd uncited budget numbers twice.
- Enable `COACH_CITATION_GATE_ENABLED`.
- Assert the endpoint response does not include the absurd numbers.
- Assert the retry-once path is exercised.

## Out of Scope

- No production code change.
- No new fallback wording.
- No Maestro run in this phase.
