# Phase 32 Verification

## Backend

Command:

```bash
cd services/backend && python3 -m pytest -q \
  tests/test_coach_chat_endpoint.py \
  tests/test_consent_guards.py \
  tests/test_coach_tool_response_migration.py \
  tests/test_coach_tool_response_v2.py \
  tests/test_coach_tool_response_v2_migration.py \
  tests/test_coach_chat_tool_use_gate.py \
  tests/coach/test_coach_chat_profile_sanitize_context_packet.py \
  tests/test_coach_tools_budget_snapshot.py \
  tests/test_citation_gate/ \
  tests/test_coach_tools_parity.py
```

Result:

```text
368 passed in 3.91s
```

## Mobile Targeted Red/Green

Command:

```bash
cd apps/mobile && flutter test test/screens/budget_screen_smoke_test.dart \
  --plain-name "BudgetContainerScreen prefers CoachProfile over stale cache"
```

Result:

```text
All tests passed
```

## Mobile Regression Set

Command:

```bash
cd apps/mobile && flutter test \
  test/domain/budget/ \
  test/data/budget/ \
  test/providers/budget/ \
  test/services/coach_chat_api_service_packet_contract_test.dart \
  test/services/coach_context_packet_payload_test.dart \
  test/services/coach_context_packet_service_test.dart \
  test/services/data_spine_service_test.dart \
  test/services/coach_chat_api_service_safe_mode_payload_test.dart \
  test/screens/budget_setup_screen_test.dart \
  test/screens/budget_screen_smoke_test.dart \
  test/screens/mon_argent_screen_test.dart \
  test/widgets/mon_argent_budget_summary_card_test.dart
```

Result:

```text
153 passed
```
