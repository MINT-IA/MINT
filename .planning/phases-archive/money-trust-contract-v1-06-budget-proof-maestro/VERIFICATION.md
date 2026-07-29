# Money Trust Contract v1 — 06 Budget Proof Maestro Verification

This verification record covers the device-level Budget and Mon Argent flow.

## Result

PASS — Maestro flow passed on iPhone 17 Pro simulator.

## Commands

- `cd apps/mobile && flutter test test/screens/budget_screen_smoke_test.dart test/services/mon_argent_coach_whisper_service_test.dart test/widgets/mon_argent_budget_summary_card_test.dart`
  - Result: `12 passed`
- `cd apps/mobile && flutter analyze --no-fatal-infos lib/screens/budget/budget_screen.dart lib/widgets/collapsible_section.dart test/screens/budget_screen_smoke_test.dart lib/services/mon_argent/coach_whisper_service.dart test/services/mon_argent_coach_whisper_service_test.dart`
  - Result: `No issues found`
- `cd apps/mobile && xattr -cr .dart_tool build ios/build && flutter build ios --simulator --debug --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true`
  - Result: built `build/ios/iphonesimulator/Runner.app`
- Installed and launched `ch.mint.app` on simulator `B03E429D-0422-4357-B754-536637D979F9`.
- `maestro test --device B03E429D-0422-4357-B754-536637D979F9 --format JUNIT --output .planning/walker/maestro-flows/mon-argent-budget-source-coherence/20260525T220249Z/result.xml --test-output-dir .planning/walker/maestro-flows/mon-argent-budget-source-coherence/20260525T220249Z --debug-output .planning/walker/maestro-flows/mon-argent-budget-source-coherence/20260525T220249Z/debug tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml`
  - Result: `1/1 Flow Passed in 39s`

## Evidence

- JUnit: `.planning/walker/maestro-flows/mon-argent-budget-source-coherence/20260525T220249Z/result.xml`
- Screenshots:
  - `mon-argent-01-data-spine.png`
  - `mon-argent-02-budget-setup.png`
  - `mon-argent-03-budget-direct-relaunch.png`
  - `mon-argent-04-coach-return.png`

## Notes

- Initial Maestro failures were selector and expansion-state issues, not number
  calculation failures.
- The detail section is now initially expanded because the formula proof is a
  trust surface, not secondary decoration.
