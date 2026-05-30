# Phase 27 — Verification

## Commands

```bash
python3 -m py_compile \
  services/backend/tests/test_coach_chat_endpoint.py
```

Result: pass.

```bash
cd services/backend && python3 -m pytest -q \
  tests/test_coach_chat_endpoint.py::TestCoachChatCitationGate::test_endpoint_blocks_uncited_absurd_budget_numbers
```

Result: `1 passed in 0.39s`.

```bash
cd services/backend && python3 -m pytest -q \
  tests/test_coach_chat_endpoint.py::TestCoachChatCitationGate::test_endpoint_blocks_uncited_absurd_budget_numbers \
  tests/coach/test_coach_chat_profile_sanitize_context_packet.py \
  tests/test_coach_tools_budget_snapshot.py \
  tests/test_citation_gate/test_budget_absurdity_numbers.py \
  tests/test_coach_tools_parity.py
```

Result: `48 passed in 0.47s`.
