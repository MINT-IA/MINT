description: Summary of Plan 54, adding data source status chips to Mon Argent situation rows.

# Summary 54 - Mon Argent Situation Status

## Outcome

Mon Argent situation rows now show whether central financial values are `saisi`, `estimé`, or `manquant`. The labels are derived from `SpineFieldMeta.confidence`, so the UI follows the data spine instead of hardcoded assumptions.

## Changed Files

- `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart`
  - Added status labels and colors for gross income, housing, LAMal, liquid savings, investments, and debt.
  - Added `_FieldStatusChip` for compact status display inside the existing situation map.
- `apps/mobile/test/screens/mon_argent_screen_test.dart`
  - Added assertions for `saisi` and `estimé`.
  - Marked investments as `FieldConfidence.estimated` in the data spine fixture.

## Verification

- `flutter test test/screens/mon_argent_screen_test.dart` - passed.
- `flutter analyze lib/screens/mon_argent/mon_argent_screen.dart test/screens/mon_argent_screen_test.dart` - no issues found.
- `flutter test test/screens/mon_argent_screen_test.dart test/widgets/mon_argent_budget_summary_card_test.dart` - passed.
- `flutter build ios --simulator --no-codesign --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true` - built `apps/mobile/build/ios/iphonesimulator/Runner.app`.
- `MINT_WALKER_ARTIFACTS=.planning/_walker/maestro-evidence-20260525T153956-plan54-compact MAESTRO_STALL_THRESHOLD=60 MAESTRO_HARD_LIMIT=300 bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml` - Maestro returned 0 on the patched build.
- `snapshot_ui` on `mintapp:///mon-argent` showed `mon_argent_situation_map` with `Revenu brut annuel / saisi`, `Investissements / estimé`, and realistic seeded values including `Logement 1'927 CHF`, `Primes maladie 420 CHF`, and `Investissements 44'460 CHF`.

## Iteration Note

The first patched Maestro run failed because the initial chip layout added too much vertical height and pushed `mon_argent_patrimoine_summary` below the expected scroll position. The chip layout was changed from a per-row column to a compact inline wrap, then the same Maestro flow returned 0.

## Follow-up

- Run the Mon Argent / Budget Maestro flow and inspect the resulting screen for numeric plausibility and layout density.
- Continue the same rule across the next central money surfaces: any projected or user-derived value should expose source, confidence, and formula context where relevant.
