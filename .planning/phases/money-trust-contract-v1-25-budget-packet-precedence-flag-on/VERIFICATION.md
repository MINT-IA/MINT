# Phase 25 — Verification

## Commands

```bash
python3 -m py_compile \
  services/backend/app/api/v1/endpoints/coach_chat.py \
  services/backend/tests/test_coach_tools_budget_snapshot.py
```

Result: pass.

```bash
cd services/backend && python3 -m pytest -q \
  tests/test_coach_tools_budget_snapshot.py::test_dispatcher_flag_on_prefers_packet_over_stale_db \
  tests/test_coach_tools_budget_snapshot.py::test_dispatcher_flag_on_preserves_liquidity_with_partial_packet \
  tests/test_coach_tools_budget_snapshot.py::test_dispatcher_flag_on_returns_camel_case_json \
  tests/test_coach_tools_budget_snapshot.py::test_legacy_formatter_prefers_coach_context_packet_budget_facts
```

Result: pass.

```bash
cd services/backend && python3 -m pytest -q \
  tests/coach/test_coach_chat_profile_sanitize_context_packet.py \
  tests/test_coach_tools_budget_snapshot.py \
  tests/test_citation_gate/test_budget_absurdity_numbers.py \
  tests/test_coach_tools_parity.py
```

Result: `46 passed in 0.41s`.

## Claude Review

Claude Opus review verdict: ship-ready from a blocking-review standpoint. It recommended preserving `months_liquidity` and adding a partial-packet test; both were implemented before closing this phase.

## Residual Risk

This guards `get_budget_status`. A future phase should add an endpoint/eval-level citation-gate test proving absurd uncited CHF amounts are rejected in the full coach response flow, not only in the citation parser unit path.
