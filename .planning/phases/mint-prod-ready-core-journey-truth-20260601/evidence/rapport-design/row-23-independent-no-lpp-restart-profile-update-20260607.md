---
description: Row 23/CJT-063 proof that independent/no-LPP Coach, Budget, and Rapport consume updated persisted income after restart.
---

# Row 23 - Independent No-LPP Restart/Profile Update

Date: 2026-06-07

## Scope

Persona: `independent_no_lpp_income_reality`.

This proof addresses the shallow-test risk raised in the Row 23 no-LPP Coach
work. A Maestro pass is not accepted here unless it proves that MINT consumes
the updated user facts after app restart instead of replaying an E2E seed or a
hardcoded transcript.

The app build used for the runtime proof does not define `MINT_E2E_ARCHETYPE`.
The profile is written through a debug-only route that calls the report
persistence store, then the app is stopped and relaunched with
`clearState: false`.

## Runtime Contract

Flow:

- `tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_restart_profile_update.yaml`

Device/build:

- `iPhone 16e - iOS 26.2`
- `flutter build ios --simulator --debug --dart-define=MINT_DISABLE_BETA_MODAL=true`
- no `MINT_E2E_ARCHETYPE`

Evidence:

- `evidence/maestro-ci/row-23-independent-no-lpp-restart-profile-update-20260607T203657/result.xml`
- `evidence/maestro-ci/row-23-independent-no-lpp-restart-profile-update-20260607T203657/watchdog-summary.txt`
- Screenshots:
  - `screenshots/row23-bootstrap-update.png`
  - `screenshots/row23-restart-updated-coach.png`
  - `screenshots/row23-restart-updated-budget.png`
  - `screenshots/row23-restart-updated-rapport.png`

Result:

- JUnit: `tests=1`, `failures=0`
- Watchdog: `maestro returned 0`
- Runtime storage mode: `storage=debugPlainFallback` on simulator, visible in
  `row23-bootstrap-update.png`.

## What The Flow Proves

1. Establishes Nadia as independent/no-LPP with annual professional net income
   `86'400 CHF` and planned 3a contribution `6'000 CHF`.
2. Updates the persisted profile to annual professional net income
   `96'000 CHF` and planned 3a contribution `6'000 CHF`.
3. Stops and relaunches the app without clearing state.
4. Opens `/coach/chat`, asks the natural prompt `Combien verser en 3a ?`, and
   verifies the answer uses:
   - `96 000 CHF/an`
   - `13 200 CHF/an`
   - `Marge 3a à vérifier`
5. Rejects stale or misleading Coach output:
   - `86'400 CHF/an`
   - `86 400 CHF/an`
   - `11'280 CHF/an`
   - `11 280 CHF/an`
   - `Donnée manquante côté MINT`
   - `Versement 3a 2026`
   - `Impact fiscal indicatif`
6. Opens `/budget` and verifies the same updated income is used as cashflow:
   - `source=derived_self_employed_annual_proxy`
   - `q_self_employed_net_income_annual_chf=96000`
   - `monthly_net=CHF 8'000`
   - formula includes `CHF 8'000`
   - rejects the stale `CHF 7'200`
7. Opens `/rapport` and verifies the same 3a basis:
   - `annual=96000`
   - `hasLpp=false`
   - `max3a=19200`
   - `planned3a=6000`
   - `remaining=13200`
   - rejects stale salaried/default values.

## Implementation Guardrails

- The E2E route is registered only under `if (!kReleaseMode)`.
- `route_guard_snapshot_test.dart` now requires debug/E2E routes to be
  immediately guarded out of release builds.
- The iOS simulator can reject secure-storage writes with a keychain
  entitlement error. The bootstrap service therefore has a debug-only
  `SharedPreferences` fallback for the known fixture path. It is unreachable in
  release and does not change production SEC-10 behavior.
- The iPhone 16e runtime proof exercises that debug simulator fallback, not a
  production keychain round trip. The `secureSeal` branch is covered by
  `debug_profile_bootstrap_service_test.dart`.
- Budget and Rapport expose machine-readable proof anchors only when
  `kReleaseMode == false`; they are absent from release builds.

## Local Proof

Focused local proof passed:

```bash
flutter test test/accessibility/coach_live_region_test.dart \
  test/screens/coach/coach_chat_test.dart \
  test/services/debug_profile_bootstrap_service_test.dart \
  test/screens/budget_screen_smoke_test.dart \
  test/screens/advisor_banking_smoke_test.dart \
  test/architecture/route_guard_snapshot_test.dart
```

Result: `128` passed, `5` existing skips.

Additional gates passed:

- `flutter analyze`
- `python3 tools/checks/maestro_locator_audit.py`
- `python3 tools/checks/route_registry_parity.py`
- `./tools/mint-routes check`
- `python3 tools/checks/cjt_context_guard.py`
- `python3 tools/checks/mint_quality_os_check.py`
- `git diff --check`

## Remaining Gaps

Row 23 remains `PARTIAL`.

This proves one non-circular restart/profile-update chain for the audited
independent/no-LPP 3a scenario. It does not yet prove:

- runtime VoiceOver/focus traversal for the same journey;
- live backend/LLM quality scoring;
- broad Coach natural-language calibration beyond the audited local topic;
- structured per-field source/timestamp/confidence UI;
- the same continuity standard across all Budget/Rapport flows and personas.
