# Phase 33 — 3a Onboarding Tax Copy Guard

## Goal

Remove misleading 3a onboarding copy that framed an estimated tax deduction as money returning to the user's account.

## Scope

- Add a widget regression test around the 3a onboarding lever scene.
- Replace guaranteed/cash-back wording with bounded fiscal wording.
- Keep the existing calculator estimate and slider behavior unchanged.

## Acceptance Criteria

- The scene no longer says the amount "retombe sur ton compte".
- The scene explicitly frames the amount as an estimated tax impact.
- Targeted widget test is green.
