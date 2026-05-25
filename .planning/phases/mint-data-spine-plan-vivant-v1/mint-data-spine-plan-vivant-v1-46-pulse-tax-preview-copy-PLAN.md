# Plan 46 — Pulse tax preview copy

## Problem

The Pulse focus selector displayed `CHF/an récupérables`, which can imply cash
back instead of an estimated tax impact.

## Scope

- Change the fiscal preview to estimated-tax wording.
- Use the structured 3a tax impact estimate.
- Add a widget regression test.

## Non-goals

- Redesign Pulse.
- Rework the focus taxonomy.

## Steps

1. Add a failing widget test for the fiscal preview.
2. Replace the copy and calculation call.
3. Run widget test and analyzer.
