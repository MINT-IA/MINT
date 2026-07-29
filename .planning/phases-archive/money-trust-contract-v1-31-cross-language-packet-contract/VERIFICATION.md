# Phase 31 — Verification

## Commands

```bash
cd services/backend && python3 -m pytest -q \
  tests/coach/test_coach_chat_profile_sanitize_context_packet.py
```

Result: `14 passed in 0.25s`.

```bash
python3 -m py_compile \
  services/backend/tests/coach/test_coach_chat_profile_sanitize_context_packet.py
```

Result: pass.

```bash
cd apps/mobile && flutter test \
  test/services/coach_context_packet_service_test.dart
```

Result: `12 passed`.
