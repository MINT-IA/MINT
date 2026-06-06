---
description: Runtime iPhone 16e proof that independent_no_lpp_income_reality reaches Budget and Rapport without salaried/LPP fallback assumptions.
status: partial-proof
date: 2026-06-06
---

# Row 23 - Independent/no-LPP Runtime Fixture Proof

## Scope

This is the runtime follow-up to CJT-061. CJT-061 fixed the local report
calculation contract for independent/no-LPP 3a assumptions. This proof adds a
canonical E2E seed and a Maestro flow for the persona
`independent_no_lpp_income_reality`.

It does not close Row 23. It proves only that the seed can reach `/rapport` and
`/budget` on a non-Pro simulator without falling back to a salaried/LPP default.

## Product Problem

Before this lot, the independent/no-LPP benchmark had local calculation proof
but no runtime fixture. A runtime run then exposed an additional wiring bug:
direct `/rapport` with the E2E seed still rendered the empty report state
(`Complète ton profil`) because the route only loaded persisted answers and did
not use `CoachProfileSeeds.activeSeed`.

## Changes

- Added `independent_no_lpp_income_reality` to `CoachProfileSeeds.registry`.
- Added seed override fields for:
  - `employmentStatus`
  - explicit monthly net income
  - LPP affiliation
  - annual 3a contribution
  - number of 3a accounts
- Mapped `CoachProfileSeeds.byArchetype('independent_no_lpp')` to the new seed.
- Added `/rapport` route fallback to use `CoachProfileSeeds.activeSeed` only
  when persisted answers are empty. This remains debug/E2E-only because
  `activeSeed` is guarded by `kReleaseMode`.
- Added Maestro flow:
  `tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_runtime.yaml`.
- Added script assertion:
  `tools/simulator/flows/maestro-perfect-set/row23_assert_independent_budget_formula.js`
  to verify the copied Budget formula contains the independent fixture values
  without making dynamic CHF strings static locators.

## Red Runtime Proof

First run, before the `/rapport` fallback fix:

```bash
MAESTRO_HARD_LIMIT=360 MAESTRO_STALL_THRESHOLD=120 \
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-independent-no-lpp-runtime-20260606T161621 \
bash tools/simulator/maestro_with_watchdog.sh test \
  --udid 9C9E9AAE-C3CF-49B8-B06D-625004880A9B \
  --debug-output .../debug \
  --format junit \
  --output .../result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_runtime.yaml
```

Result:

- Device: `iPhone 16e - iOS 26.2 - 9C9E9AAE-C3CF-49B8-B06D-625004880A9B`
- JUnit: `tests=1`, `failures=1`
- Failure: `Assertion is false: "Transparence et conformité" is visible`
- Screenshot showed the empty report state, not the seeded report:
  `evidence/maestro-ci/row-23-independent-no-lpp-runtime-20260606T161621/01-red-empty-rapport.png`

## Green Runtime Proof

Build:

```bash
cd apps/mobile
flutter build ios --simulator --debug \
  --dart-define=MINT_E2E_ARCHETYPE=independent_no_lpp_income_reality \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Result:

- `Xcode build done`
- `Built build/ios/iphonesimulator/Runner.app`

Initial green run:

```bash
MAESTRO_HARD_LIMIT=360 MAESTRO_STALL_THRESHOLD=120 \
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-independent-no-lpp-runtime-20260606T161913 \
bash tools/simulator/maestro_with_watchdog.sh test \
  --udid 9C9E9AAE-C3CF-49B8-B06D-625004880A9B \
  --debug-output .../debug \
  --format junit \
  --output .../result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_runtime.yaml
```

Result:

- Device: `iPhone 16e - iOS 26.2 - 9C9E9AAE-C3CF-49B8-B06D-625004880A9B`
- JUnit: `tests=1`, `failures=0`
- Maestro: `1/1 Flow Passed in 22s`
- Watchdog: `maestro returned 0`
- Runtime folder:
  `evidence/maestro-ci/row-23-independent-no-lpp-runtime-20260606T161913/`

Claude CLI review then flagged that the initial flow had too many negative
assertions and too little positive proof of the independent fixture values. The
flow was strengthened with:

- positive `/rapport` assertion:
  `Plafond 3a selon affiliation LPP et statut de revenu`
- script assertion on `budget_hero_formula` requiring:
  - `CHF 7'200`
  - `CHF 3'333`

Strengthened rerun:

```bash
MAESTRO_HARD_LIMIT=360 MAESTRO_STALL_THRESHOLD=120 \
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-independent-no-lpp-runtime-strong-20260606T162641 \
bash tools/simulator/maestro_with_watchdog.sh test \
  --udid 9C9E9AAE-C3CF-49B8-B06D-625004880A9B \
  --debug-output .../debug \
  --format junit \
  --output .../result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_runtime.yaml
```

Result:

- Device: `iPhone 16e - iOS 26.2 - 9C9E9AAE-C3CF-49B8-B06D-625004880A9B`
- JUnit: `tests=1`, `failures=0`
- Maestro: `1/1 Flow Passed in 22s`
- Watchdog: `maestro returned 0`
- Runtime folder:
  `evidence/maestro-ci/row-23-independent-no-lpp-runtime-strong-20260606T162641/`

Manual screenshots on the same installed build after the strengthened rerun:

- `/budget`:
  `evidence/maestro-ci/row-23-independent-no-lpp-runtime-strong-20260606T162641/01-row23-independent-no-lpp-budget.png`
- `/rapport`:
  `evidence/maestro-ci/row-23-independent-no-lpp-runtime-strong-20260606T162641/02-row23-independent-no-lpp-rapport.png`

## User-Visible Outcome

- `/budget` renders a populated cashflow surface with `CHF 7'200` monthly
  resources, `CHF 3'333` monthly free in the hero formula, and no
  `Ajouter mon salaire` empty-state CTA.
- `/rapport` renders a seeded synthesis for a `39 ans • VD • single` profile.
- `/rapport` shows the compliance block with:
  `Plafond 3a selon affiliation LPP et statut de revenu`.
- The flow asserts absence of:
  - `Plafond 3a salarié`
  - `Ajouter mon salaire`
  - `salarié uniquement`
  - `7’258`
  - `NaN`
  - `Infinity`
  - Flutter/runtime exception strings

## Quality OS Interpretation

This raises the independent/no-LPP benchmark from "runtime fixture missing" to
"runtime fixture and first flow passed." It still does not provide a full
expert-grade benchmark score.

## FATCA Seed Non-Regression

Claude CLI final review noted that the seed refactor changes the old
`julien_expat_us` wizard answer shape: `q_savings_allocation` no longer includes
`3a` when the seed has no LPP affiliation and no annual 3a contribution. This is
the intended safer behavior for the FATCA fixture, because it prevents a
synthetic planned 3a contribution from being created by the allocation fallback.

Added test:

```bash
cd apps/mobile
flutter test test/services/coach_profile_seeds_test.dart
```

Result:

- `14/14` tests passed.
- New guard: `seed_julien_expat_us_does_not_plan_3a_contributions`.

Runtime non-regression:

```bash
cd apps/mobile
flutter build ios --simulator --debug \
  --dart-define=MINT_E2E_ARCHETYPE=expat_us \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Then:

```bash
MAESTRO_HARD_LIMIT=240 MAESTRO_STALL_THRESHOLD=90 \
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-fatca-seed-nonregression-20260606T163351 \
bash tools/simulator/maestro_with_watchdog.sh test \
  --udid 9C9E9AAE-C3CF-49B8-B06D-625004880A9B \
  --debug-output .../debug \
  --format junit \
  --output .../result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_fatca_3a_gate.yaml
```

Result:

- Device: `iPhone 16e - iOS 26.2 - 9C9E9AAE-C3CF-49B8-B06D-625004880A9B`
- JUnit: `tests=1`, `failures=0`
- Maestro: `1/1 Flow Passed in 13s`
- Watchdog: `maestro returned 0`
- Runtime folder:
  `evidence/maestro-ci/row-23-fatca-seed-nonregression-20260606T163351/`

Remaining gaps:

- Expert guidance scoring against the persona-flow rubric.
- VoiceOver/focus traversal.
- PDF export content for the same persona.
- A true AVS-determining independent-income field rather than using the
  captured monthly income as the current report proxy.
- Broader natural-language Coach guidance for this persona.
