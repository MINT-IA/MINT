---
id: CJT-009
date: 2026-06-02
status: verified
area: coach-navigation
---

# CJT-009 — Phase-specific Coach route hints

## Finding

`ContextInjectorService._buildRelevantScreens()` trusted lifecycle adaptation
tags first, then filled remaining slots from every chat-routable
`decisionCanvas` in `MintScreenRegistry`. When lifecycle tags drifted from the
registry, the Coach context could show unrelated generic route hints.

Concrete repro:

- Transmission lifecycle tags included `succession`, `donation_simulator`, and
  `advance_directive`.
- Registry intent tags include `succession_patrimoine` and
  `life_event_donation`.
- Before the fix, an elder transmission profile received retirement route hints
  such as `retirement_choice` and `retirement_projection`.

## Fix

- Resolve known lifecycle tag drift through explicit intent aliases into the
  existing `MintScreenRegistry`.
- Remove the generic decision-canvas fallback.
- Keep unknown lifecycle tags absent instead of silently filling with unrelated
  screens.

The alias table is structural route compatibility, not regulatory data or
localized copy. The screen registry remains the route source of truth.

## Red Proof

Command:

```sh
cd apps/mobile && flutter test test/services/context_injector_service_test.dart --plain-name "relevantScreens stay phase-specific when lifecycle tags drift"
```

Observed before fix:

- Exit code: `1`
- Actual relevant screens:
  - `retirement_choice`
  - `retirement_projection`
  - `preretraite_complete`
  - `simulator_3a`
  - `tax_optimization_3a`

## Green Proof

Focused regression:

```sh
cd apps/mobile && flutter test test/services/context_injector_service_test.dart --plain-name "relevantScreens stay phase-specific when lifecycle tags drift"
```

Result:

- Exit code: `0`
- `00:00 +1: All tests passed!`

Targeted navigation/lifecycle regression:

```sh
cd apps/mobile && flutter test test/services/context_injector_service_test.dart test/services/lifecycle/lifecycle_detector_test.dart test/services/navigation/screen_registry_test.dart test/services/navigation/route_planner_test.dart
```

Result:

- Exit code: `0`
- `00:00 +179: All tests passed!`

Static analysis:

```sh
cd apps/mobile && flutter analyze
```

Result:

- Exit code: `0`
- `No issues found!`
