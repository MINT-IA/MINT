# Phase 24 — Verification

## Commands

```bash
python3 -m py_compile \
  services/backend/app/api/v1/endpoints/coach_chat.py \
  services/backend/app/services/coach/context_packet_sanitizer.py \
  services/backend/tests/coach/test_coach_chat_profile_sanitize_context_packet.py
```

Result: pass.

```bash
cd services/backend && python3 -m pytest -q \
  tests/coach/test_coach_chat_profile_sanitize_context_packet.py \
  tests/test_coach_tools_budget_snapshot.py \
  tests/test_citation_gate/test_budget_absurdity_numbers.py
```

Result: `26 passed in 0.37s`.

## Agent Review

- Architecture agent confirmed the duplication risk and recommended delegation to a shared sanitizer.
- QA agent recommended the exact sanitizer parity test plus the budget/citation test set before the next Maestro round.

## Residual Risk

The next P0 test gap is `get_budget_status` with server-side budget flag ON and stale/absurd DB values. That should be handled before the next broad Maestro run.

