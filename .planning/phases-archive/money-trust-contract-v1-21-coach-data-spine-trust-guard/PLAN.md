# Phase 21 — Coach Data Spine Trust Guard

## Goal
Prevent the coach context from treating profile defaults or stale mobile fields as user-trusted financial facts.

## Problem
Phases 19-20 made `BudgetInputs` trust-aware, but the coach data spine still promoted profile amounts when `userProvidedFields` was empty. That meant a default rent, LAMal premium, liquid savings, or debt value could be exposed as a structured coach fact even when the budget read model considered it missing.

## Scope
- Keep the existing `BudgetInputs` contract unchanged.
- Tighten `DataSpineService` so explicit situation amounts require either a matching `userProvidedFields` entry or a non-estimated data source.
- Emit missing budget fields in `CoachContextPacketService` when housing or LAMal are absent from the trustable spine.
- Align backend packet allowlists with the mobile packet IDs and field paths.

## Non-Goals
- Do not change live LLM behavior directly.
- Do not rewrite `get_budget_status`.
- Do not run a live LLM Maestro flow as the primary assertion.

## Verification Plan
- Flutter tests for data spine and coach packet behavior.
- Backend pytest for sanitizer pass-through and nested PII filtering.
- Targeted Dart analyze and Python compile checks.
- Claude Opus review through `tools/claude_review.sh`.

