phase: mon-argent-budget-cleanup-v2
plan: 36
title: Backend budget fallback read-model alignment
branch: codex/mon-argent-budget-cleanup-v2
date: 2026-05-27

# Phase 36 — Backend budget fallback read-model alignment

The live coach path is packet-first when `coach_context_packet` carries valid
budget facts. The remaining architecture gap was the authenticated backend
fallback used when the packet is absent or invalid: it only read old flat
`monthly_income` / `monthly_expenses` fields and could diverge from the budget
CRUD read model stored in `ProfileModel.data["budget"]`.

## Changes

- `CoachingEngine.compute_budget_snapshot()` now prefers
  `ProfileModel.data["budget"]`, matching `/api/v1/budget/me` semantics:
  - income override when present,
  - otherwise `incomeNetMonthly`,
  - fixed lines + variable target + savings target as monthly expenses.
- Numeric budget values serialized as strings, including Swiss apostrophe
  grouping such as `5'379`, are parsed instead of being silently dropped.
- The old flat fields remain as a legacy fallback only when no budget read model
  is available.
- `docs/coach-tool-routing.md` now documents the real destination and fallback
  chain for `get_budget_status`.

## Verification

- Red first:
  - `pytest -q tests/test_coach_tools_budget_snapshot.py -q`
  - Result before implementation: 2 failures proving stale legacy fields won.
- Green after implementation:
  - `pytest -q tests/test_coach_tools_budget_snapshot.py tests/test_budget_crud.py`
  - Result: `29 passed in 2.22s`.
- `python3 -m ruff check app/services/coaching_engine.py tests/test_coach_tools_budget_snapshot.py`
  - Result: `All checks passed!`.

## Expert Review

Architect-review verdict was `BLOCKED` before this phase because the backend was
only packet-preferred, and the DB fallback ignored `ProfileModel.data["budget"]`.
This phase resolves that exact gap while preserving the packet-first short
circuit and legacy fallback behavior.
