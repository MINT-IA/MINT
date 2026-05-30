# Phase 30 — Verification

## Commands

```bash
cd apps/mobile && flutter test \
  test/services/coach_chat_api_service_packet_contract_test.dart
```

Result: `2 passed`.

```bash
cd apps/mobile && flutter test \
  test/services/coach_chat_api_service_packet_contract_test.dart \
  test/services/coach_context_packet_payload_test.dart \
  test/services/coach_context_packet_service_test.dart \
  test/services/data_spine_service_test.dart
```

Result: `30 passed`.
