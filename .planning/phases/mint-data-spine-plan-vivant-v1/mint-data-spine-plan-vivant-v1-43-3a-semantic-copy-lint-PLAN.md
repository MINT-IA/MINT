# Plan 43 — 3a semantic copy lint

## Problem

Plans 41 and 42 fixed concrete 3a wording bugs. The remaining risk is relapse:
`7'258` or `36'288` gets presented as tax reduction instead of deductible room.

## Scope

- Deterministic ARB lint for ceiling + tax-saving wording in one sentence.
- FR/en/de/es/it/pt vocabulary, local pre-commit, GitHub Actions.

## Non-goals

- Real 3a tax-impact calculator or coach/budget projection rewrite.
- Docs, test narratives, backend fixtures.

## Steps

1. Add a failing pure-Python self-test for ceiling-as-tax-saving copy.
2. Implement `tools/checks/no_3a_ceiling_as_tax_saving.py`.
3. Add `lefthook` and CI gates; verify lint, ARB parity, YAML, diff hygiene.

## Acceptance Criteria

- Reject `7258 CHF d'économie d'impôt`.
- Allow `7'258 CHF déductibles`.
- Allow separate estimated tax-impact sentence.
