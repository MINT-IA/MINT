TLDR: Phase 70 fixed the live `/budget` relaunch regression found by Maestro after saving budget-first data, made the budget calculation disclosure a real tappable semantics control, and re-ran the Mon Argent -> Budget -> Coach flow successfully on the iPhone simulator.

# Phase 70 — Budget relaunch + Maestro proof

Date: 2026-05-28

## Problem

The Maestro flow `flow_mon_argent_budget_setup_spine.yaml` proved a real product bug:

- enter housing `2200` and LAMal `420` in `/budget/setup`;
- save;
- stop and relaunch the app;
- deep link to `/budget`;
- expected: `budget_screen`;
- actual before fix: the empty "Poser mes charges" state.

Root cause: `BudgetContainerScreen` hydrated once while `CoachProfileProvider` was not loaded yet. With no direct `budget_inputs_v1` cache, it showed the empty state and never rehydrated when the profile later loaded from `wizard_answers_v2`.

## Changes

- `BudgetContainerScreen` now listens to `CoachProfileProvider` and rehydrates `BudgetProvider` when profile state becomes usable.
- Existing semantics are preserved for storage, full profile, partial profile, and debt hydration paths.
- `BudgetScreen` replaces the calculation `ExpansionTile` wrapper with a local tappable disclosure that exposes `budget_calculation_detail_toggle` as a real semantics tap action.
- The Maestro flow now asserts the always-visible `budget_hero_formula` for deterministic formula proof and keeps the disclosure id as a structural anchor.

## Verification

- Red test first:
  - `flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetContainerScreen hydrates budget-first wizard answers after profile load"` failed before the container fix, then passed.
  - `flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetScreen exposes Maestro semantics anchors"` failed before the tappable disclosure fix, then passed.
- Full targeted suite:
  - `flutter test test/screens/budget_screen_smoke_test.dart` -> 14 tests passed.
  - `flutter analyze lib/screens/budget/budget_container_screen.dart lib/screens/budget/budget_screen.dart test/screens/budget_screen_smoke_test.dart` -> no issues.
  - `python3 tools/checks/budget_read_contract.py` -> OK.
  - `python3 tools/checks/wiki_lint.py lint` -> no FAIL-level violations, 139 pre-existing warnings.
  - YAML parse for `flow_mon_argent_budget_setup_spine.yaml` -> OK.
- Simulator:
  - `flutter build ios --simulator --debug --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true -v` -> build succeeded after one transient CodeSign rerun.
  - `maestro test --debug-output /tmp/mint-maestro-mon-argent-phase70 tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml` -> PASS on iPhone 17 Pro iOS 26.2.

## Maestro assertions now covered

- Mon Argent data-spine summary and section selector.
- Situation map groups: month, wealth, pension.
- Direct section aliases: month, wealth, pension, future.
- Budget setup fields and live total.
- Relaunch `/budget` after save.
- Budget formula visible with `CHF 3'078` charges and `CHF 1'922` available.
- Absurd-value guards: no `19'272'200`, no `420'420`.
- Return to Coach with input, lightning menu, and send anchors.

## Follow-up

The calculation disclosure expands correctly in Flutter widget tests and with simulator coordinate taps, but Maestro iOS did not dispatch `tapOn id` or `tapOn text` to Flutter for this specific disclosure. The flow therefore validates the visible formula proof and leaves disclosure expansion to widget coverage.
