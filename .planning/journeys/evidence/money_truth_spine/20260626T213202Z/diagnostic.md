# JOS-002 Money Truth Spine Red Runtime Diagnostic

Run: `20260626T213202Z`

Fresh Maestro diagnostic rerun on `codex/jos002-money-truth-spine-20260626`
with a temporary local harness alignment reached:

- current `/onb` onboarding entry and retirement intent
- local-mode gate acceptance
- `/budget/setup`
- budget input save for housing `2200` and LAMal `420`
- app restart
- `/budget` with `budget_screen`, `budget_calculation_detail_toggle`, and `budget_hero_formula`

It failed at `/mon-argent?section=month`:

```xml
<failure>Assertion is false: id: mon_argent_screen is visible</failure>
```

Simulator state after failure showed `/onb`, not Mon Argent. Local preferences
contained `auth_local_mode=true` and `budget_inputs_v1`, but no
`wizard_answers_v2`. This matches the existing SEC-10 simulator path:
`ReportPersistenceService.saveAnswers()` returns false when secure storage
cannot seal sensitive fields, so onboarding creates only a session profile.
After restart, `/mon-argent` requires a hydrated `CoachProfile` and correctly
redirects to `/onb`.

Interpretation: red runtime evidence for production-onboarding persistence on
simulator, not a Money Truth value mismatch. Downstream Budget proof did pass
through restart before the Mon Argent redirect.

The temporary harness alignment updated only the stale Maestro onboarding
locators to the current `/onb` storyboard. It is intentionally not committed in
this Journey OS tracking PR because `journey_os_check.py` rejects simulator
flow files outside `.planning/journeys/**`. Land any YAML proof fix in a
separate runtime-proof PR.
