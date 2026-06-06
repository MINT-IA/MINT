# Row 23 - Budget allocation copy runtime proof

## Scope

Follow-up to the populated `/budget` Row 23 runtime review for the
`independent_no_lpp_income_reality` persona.

The first runtime pass surfaced a content-quality issue: the budget hero used
`Disponible ce mois` for the canonical remainder after planned savings
(`CHF 3'333`), while the donut center also said `Disponible` for the broader
capacity before planned savings (`CHF 3'833`).

## Fix

- The `SpendingMeter` center label now describes allocation capacity, not free
  monthly money:
  - FR: `À répartir`
  - EN: `To allocate`
  - DE: `Zu verteilen`
  - ES: `Por repartir`
  - IT: `Da ripartire`
  - PT: `A distribuir`
- The Row 23 independent/no-LPP Maestro flow now asserts `À répartir` on
  `/budget`.
- Added an isolated widget regression:
  `apps/mobile/test/widgets/budget/spending_meter_test.dart`.

## Verification

```bash
flutter test test/widgets/budget/spending_meter_test.dart test/screens/budget_screen_smoke_test.dart test/accessibility/primary_screen_dynamic_type_test.dart
# 23/23 pass

flutter gen-l10n
python3 tools/checks/arb_parity.py
# OK - 6 locale(s) parity (reference=fr, 6875 keys each).

flutter analyze
# No issues found.

python3 tools/checks/mint_quality_os_check.py
python3 tools/checks/cjt_context_guard.py
python3 tools/checks/maestro_locator_audit.py
./tools/mint-routes check
git diff --check
# all OK
```

Runtime proof:

```bash
flutter build ios --simulator --debug \
  --dart-define=MINT_E2E_ARCHETYPE=independent_no_lpp_income_reality \
  --dart-define=MINT_DISABLE_BETA_MODAL=true

MAESTRO_HARD_LIMIT=360 MAESTRO_STALL_THRESHOLD=120 \
  MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-allocation-copy-runtime-20260606T175859 \
  bash tools/simulator/maestro_with_watchdog.sh test --format junit \
  --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-budget-allocation-copy-runtime-20260606T175859/result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_runtime.yaml
```

Result:

- Device: `iPhone 16e - iOS 26.2`
- JUnit: `tests=1`, `failures=0`
- Watchdog: `maestro returned 0`
- Screenshot: `evidence/maestro-ci/row-23-budget-allocation-copy-runtime-20260606T175859/row23-independent-no-lpp-budget.png`

## Residual Risk

This fixes one first-viewport terminology conflict on `/budget`. Row 23 remains
`PARTIAL`: broader screen and flow quality review is still required for all
primary surfaces, including expert guidance scoring and VoiceOver traversal.
