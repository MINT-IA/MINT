# Plan 39 — Budget implausible amount guard

## Problem

The monthly budget screen can render impossible monthly charges after a field
entry drift. The observed case showed housing near CHF 19.3M and LAMal near
CHF 420k. The likely failure mode is an input value being appended to an
existing prefilled value, then persisted without a domain guard.

## Scope

- Budget setup input behavior.
- Budget capture validation before persistence.
- Budget domain rebuild from `wizard_answers_v2` and `CoachProfile`.
- Coach profile rebuild from wizard answers.
- Localized error copy and data-flow documentation.

## Non-goals

- Redesigning the full budget visualization.
- Changing tax or insurance estimation formulas.
- Adding a new backend contract.

## Implementation Plan

1. Select the full field value on tap so Maestro/manual replacement does not
   append to prefilled monthly amounts.
2. Reject implausible monthly charges in `BudgetSetupScreen` before writing
   answers.
3. Apply the same monthly amount guard when rebuilding `BudgetInputs` and
   `CoachProfile`, so stale simulator data cannot keep appearing as real
   monthly charges.
4. Add tests at UI, domain, and profile rebuild levels.
5. Regenerate l10n after adding the localized validation message.
6. Verify with targeted Flutter tests, analyze, ARB parity, design lints, and
   the Mon Argent → Budget → relaunch → Coach Maestro flow.

## Acceptance Criteria

- Entering `19272200` for housing or `420420` for LAMal does not persist.
- Existing stale implausible values are dropped when deriving budget inputs.
- Direct `/budget` relaunch cannot render those stale values.
- Valid monthly values such as CHF 2'200 housing and CHF 420 LAMal still save.
- The regression is covered by automated tests.
