# Plan 50 — 3a estimate-first copy

## Problem

The 3a simulator passed Maestro after Plan 49, but the screen still used
overconfident wording:

- `Gain fiscal annuel`
- `Stratégie gagnante`
- copy implying a 100% equity allocation could maximize capital

For Mint, a simulator result must read as an estimate from user-controlled
parameters, not as an answer to follow.

## Scope

- Rewrite the 3a simulator copy in all 6 ARB locales.
- Regenerate Flutter localizations.
- Update the 3a Maestro flow anchors and FATCA negative assertion.
- Add a widget regression test that blocks the old French labels.

## Non-goals

- Change the 3a calculator formula.
- Change Swiss 3a constants.
- Redesign the 3a screen layout.

## Steps

1. Add a failing widget test for estimate-first copy.
2. Update ARB strings and generated localizations.
3. Update Maestro flow labels.
4. Run targeted tests, lints, and Maestro.
