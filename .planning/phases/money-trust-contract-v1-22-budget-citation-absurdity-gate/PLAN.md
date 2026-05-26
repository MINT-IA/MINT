# Phase 22 — Budget Citation Absurdity Gate

## Goal
Pin the backend citation gate against absurd budget and tax numbers before they can reach the user.

## Scope
- Add deterministic citation-gate tests for uncited CHF/% budget claims.
- Keep the gate rule simple: numbers need citations; plausibility belongs to upstream calculators and clamps.

## Verification
- `cd services/backend && python3 -m pytest -q tests/test_citation_gate/test_budget_absurdity_numbers.py tests/test_citation_gate/test_number_detection.py`

