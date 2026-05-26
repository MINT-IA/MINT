# Phase 28 — Verification

## Commands

```bash
python3 -m py_compile \
  services/backend/app/api/v1/endpoints/coach_chat.py \
  services/backend/app/services/coach/context_packet_sanitizer.py \
  services/backend/tests/test_coach_tools_budget_snapshot.py \
  services/backend/tests/coach/test_coach_chat_profile_sanitize_context_packet.py
```

Result: pass.

```bash
cd services/backend && python3 -m pytest -q \
  tests/coach/test_coach_chat_profile_sanitize_context_packet.py \
  tests/test_coach_tools_budget_snapshot.py
```

Result: `29 passed in 0.34s`.
