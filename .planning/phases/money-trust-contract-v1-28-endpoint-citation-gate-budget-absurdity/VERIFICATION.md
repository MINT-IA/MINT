# Phase 28 — Verification

## Commands

```bash
python3 -m py_compile services/backend/tests/test_narrator_refuses_uncited_numbers.py
```

Result: pass.

```bash
cd services/backend && python3 -m pytest -q \
  tests/test_narrator_refuses_uncited_numbers.py \
  tests/test_citation_gate/test_budget_absurdity_numbers.py \
  tests/test_citation_gate/test_retry_flow.py
```

Result: `13 passed in 0.11s`.

## Residual Risk

This covers repeated uncited number rejection at endpoint level. The next simulator run should still validate the visible budget/coach journey because UI state can diverge from backend guarantees.
