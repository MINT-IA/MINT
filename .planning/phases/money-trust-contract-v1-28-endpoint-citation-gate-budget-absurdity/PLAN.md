# Phase 28 — Endpoint Citation Gate Budget Absurdity

## Goal

Prove that absurd uncited CHF values cannot reach the user through the real `/coach/chat` endpoint response path.

## Problem

Phase 22 covered the citation parser directly. That was necessary but not sufficient: Mint also needs an endpoint-level regression proving the retry/fallback wrapper actually protects the user-facing response when the narrator emits an uncited financial number.

## Scope

- Replace the old skipped anticipation test with an active endpoint test.
- Enable `COACH_CITATION_GATE_ENABLED` in-test.
- Mock the narrator/orchestrator to emit the same absurd uncited budget amount on both first pass and retry.
- Assert the endpoint returns the templated fallback and never returns the absurd CHF amount.

## Out of Scope

- No prompt changes.
- No new citation grammar.
- No UI changes.
- No Maestro run; this is a backend trust gate prerequisite.

## Verification Plan

- Compile the new endpoint test.
- Run the endpoint test with the existing budget absurdity parser tests and retry-flow tests.
- Re-run the broader backend trust set before moving to simulator flows.
