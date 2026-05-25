# Plan 41 — 3a opener tax wording guard

## Problem

The coach opener displayed `7'258 CHF` as an `économie d'impôt`, but that
number is the salaried LPP 3a annual ceiling. The message confused the
deductible contribution room with the estimated tax reduction.

## Scope

- `openerSavingsOpportunity` copy in the 6 ARB locales.
- Generated Flutter localizations.
- Regression coverage in `DataDrivenOpenerService`.

## Non-goals

- Changing the 3a ceiling constants.
- Adding a full canton-aware tax estimate to this opener.
- Redesigning the coach opener priority logic.

## Implementation Plan

1. Keep the existing `plafond` parameter as contribution-room data.
2. Rewrite the message to say the amount is still deductible, not an estimated
   tax reduction.
3. Regenerate Flutter localization classes.
4. Add a regression assertion blocking the old French wording.
5. Verify ARB parity, LSFin banned-term scan, accent lint, targeted coach
   tests, and Flutter analysis.

## Acceptance Criteria

- The coach no longer renders `7'258 CHF d'économie d'impôt en jeu`.
- The message still surfaces the 3a contribution-room value.
- Cached/precomputed coach insight rendering uses the corrected localization.
