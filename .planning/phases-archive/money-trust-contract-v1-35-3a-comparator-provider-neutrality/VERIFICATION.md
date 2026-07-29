# Phase 35 Verification

## Widget Test

Command:

```bash
cd apps/mobile && flutter test test/widgets/comparators/pillar3a_comparator_widget_test.dart
```

Result:

```text
All tests passed
```

## Regression Bundle

Commands:

```bash
cd apps/mobile && flutter test \
  test/data/financial_explanations_test.dart \
  test/screens/onboarding/mvp_wedge/mint_scene_3a_levier_test.dart \
  test/widgets/comparators/pillar3a_comparator_widget_test.dart \
  test/screens/budget_screen_smoke_test.dart \
  test/services/coach_chat_api_service_packet_contract_test.dart

cd services/backend && python3 -m pytest -q \
  tests/coach/test_coach_chat_profile_sanitize_context_packet.py \
  tests/test_coach_tools_budget_snapshot.py \
  tests/test_coach_chat_endpoint.py
```

Results:

```text
Mobile: 13 passed
Backend: 76 passed
git diff --check: clean
```
