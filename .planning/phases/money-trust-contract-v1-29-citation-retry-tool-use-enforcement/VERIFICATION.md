# Phase 29 — Verification

## Commands

```bash
python3 -m py_compile \
  services/backend/app/api/v1/endpoints/coach_chat.py \
  services/backend/tests/test_coach_chat_endpoint.py
```

Result: pass.

```bash
cd services/backend && python3 -m pytest -q \
  tests/test_coach_chat_endpoint.py::TestCoachChatCitationGate \
  tests/test_coach_chat_tool_use_gate.py
```

Result: `17 passed in 0.42s`.

```bash
cd services/backend && python3 -m pytest -q \
  tests/test_coach_chat_endpoint.py::TestCoachChatCitationGate \
  tests/test_coach_chat_tool_use_gate.py \
  tests/coach/test_coach_chat_profile_sanitize_context_packet.py \
  tests/test_coach_tools_budget_snapshot.py \
  tests/test_citation_gate/test_budget_absurdity_numbers.py \
  tests/test_coach_tools_parity.py
```

Result: `67 passed in 0.49s`.
