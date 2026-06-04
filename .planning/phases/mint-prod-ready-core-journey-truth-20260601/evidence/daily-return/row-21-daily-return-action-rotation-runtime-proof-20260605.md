# Row 21 — daily return action rotation runtime proof — 2026-06-05

## Status

`PARTIAL`.

This proof closes the runtime-visible acknowledgement loop for the current
`Cap du jour` card. It does **not** claim true financial task completion:
`completedActions` must still be written only after a target flow returns with a
meaningful profile/state change.

## Bug Found

The earlier Row 21 flow was green because it only proved:

- `/home` showed a `Cap du jour`,
- `Simule` routed to Explorer,
- the app did not hit `Page introuvable`.

That was not sufficient product proof. Manual runtime inspection after the
green flow showed the same 3a cap still visible after returning to
`Aujourd'hui`, creating a sticky daily loop instead of a useful next priority.

## Change Covered

- `CapDuJourBanner` records a visible card tap as served via
  `CapMemoryStore.markServed(...)`.
- The acknowledgement writes `lastCapServed` / `lastCapDate`, not
  `completedActions`.
- The banner recomputes from `CoachProfileProvider.profile` when available,
  and falls back to `MintStateProvider.state.profile` when the Coach profile
  provider is not ready.
- `CapEngine` now considers up to five `ResponseCardService` fallback cards
  when the main rules have no candidates, so recency can choose another useful
  fallback instead of always returning the same first fallback card.
- `MintShell` tab icons expose stable runtime identifiers
  `nav_tab_aujourdhui`, `nav_tab_mon_argent`, `nav_tab_coach`, and
  `nav_tab_explorer` for reliable Maestro navigation.

## Runtime Evidence

Build:

```bash
cd apps/mobile
CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
```

Flow:

```bash
MAESTRO_HARD_LIMIT=300 MAESTRO_STALL_THRESHOLD=90 \
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-21-daily-return-action-rotation-20260605T014909 \
  bash tools/simulator/maestro_with_watchdog.sh test \
  --format junit \
  --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-21-daily-return-action-rotation-20260605T014909/result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row21_daily_return_action_rotation.yaml
```

Result:

- JUnit: `tests=1`, `failures=0`, `time=23.0`.
- Watchdog: `EXIT_CODE=0`.
- Device: iPhone 17 Pro iOS 26.2 simulator
  `B03E429D-0422-4357-B754-536637D979F9`.

Artifacts:

- `evidence/maestro-ci/row-21-daily-return-action-rotation-20260605T014909/result.xml`
- `evidence/maestro-ci/row-21-daily-return-action-rotation-20260605T014909/maestro.log`
- `evidence/maestro-ci/row-21-daily-return-action-rotation-20260605T014909/row21-next-priority-after-return.jpg`

The final runtime snapshot after returning to `Aujourd'hui` exposed:

```text
cap_du_jour_rc_tax_optimization
Cap du jour : Optimisation fiscale
Déductions indicatives à vérifier
Découvrir mes déductions
```

The previous served card id `cap_du_jour_rc_pillar_3a_2026` was no longer
visible.

## Deterministic Evidence

```bash
cd apps/mobile
flutter test \
  test/widgets/aujourdhui/cap_du_jour_banner_test.dart \
  test/services/cap_engine_test.dart \
  test/widgets/mint_shell_flag_gate_test.dart
```

Result: `82` tests passed.

```bash
cd apps/mobile
flutter analyze \
  lib/widgets/aujourdhui/cap_du_jour_banner.dart \
  lib/services/cap_engine.dart \
  lib/widgets/mint_shell.dart \
  test/widgets/aujourdhui/cap_du_jour_banner_test.dart \
  test/services/cap_engine_test.dart \
  test/widgets/mint_shell_flag_gate_test.dart
```

Result: no issues found.

## Runtime Guidance Quality Review

- `mechanical proof`: Maestro proves `/home -> Simule -> Explorer ->
  Aujourd'hui` and asserts the initially served `cap_du_jour_rc_pillar_3a_2026`
  is not visible after return.
- `user-visible outcome`: the user returns to `Aujourd'hui` and sees
  `Optimisation fiscale` / `Découvrir mes déductions` instead of the same 3a
  pressure.
- `guidance quality`: the daily surface now advances to another plausible
  financial priority after acknowledgement.
- `non-absurd`: avoids a sticky loop where the app asks for the same action
  immediately after the user selected it.
- `inclusive`: no salary-only, employee-only, or unsupported-archetype copy was
  introduced.
- `financial trust`: acknowledgement is separated from completion; no real
  financial task is marked complete by a navigation tap.
- `remaining qualitative gaps`: Row 21 still needs true target-flow completion
  proof before `completedActions` can be written, plus broader recurrence proof
  across multiple daily-return priorities and dates.

## Scope Limit

This is a Row 21 runtime-visible acknowledgement/rotation proof. It does not
close Row 18 action completion, authenticated restart continuity, live Coach
quality, or backend fact persistence.
