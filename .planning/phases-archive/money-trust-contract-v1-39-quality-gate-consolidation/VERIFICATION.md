# Phase 39 — Verification

## Backend

```sh
python3 -m pytest -q \
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

Result: `368 passed in 4.04s`.

## Mobile

```sh
flutter test \
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
  test/widgets/mon_argent_budget_summary_card_test.dart \
  test/data/financial_explanations_test.dart \
  test/widgets/comparators/pillar3a_comparator_widget_test.dart \
  test/screens/onboarding/mvp_wedge/mint_scene_3a_levier_test.dart \
  test/services/notification_scheduler_service_test.dart \
  test/services/reengagement_engine_test.dart
```

Result: `205` tests passed.

## Analyze

```sh
flutter analyze \
  lib/data/financial_explanations.dart \
  lib/widgets/comparators/pillar3a_comparator_widget.dart \
  lib/services/notification_scheduler_service.dart \
  lib/services/reengagement_engine.dart \
  test/data/financial_explanations_test.dart \
  test/widgets/comparators/pillar3a_comparator_widget_test.dart \
  test/services/notification_scheduler_service_test.dart \
  test/services/reengagement_engine_test.dart
```

Result after const cleanup: `No issues found`.

## Build and Maestro

```sh
xattr -cr build/ios ios/Flutter
CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Result: `✓ Built build/ios/iphonesimulator/Runner.app`.

```sh
xattr -cr apps/mobile/build/ios/iphonesimulator/Runner.app
timeout 30s xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app
MAESTRO_HARD_LIMIT=300 MAESTRO_STALL_THRESHOLD=90 \
  bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml
```

Result: Maestro exit `0`.

Artifact: `.planning/_walker/20260526T163138/maestro.log`.

## Diff Hygiene

```sh
git diff --check
```

Result: pass after normalizing generated l10n line endings.
