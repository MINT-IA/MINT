# Plan 42 — 3a semantic label sweep

## Problem

Plan 41 fixed the coach opener, but the same semantic bug class can appear
elsewhere: a legal 3a contribution ceiling is displayed as if it were a tax
reduction. A correct number with the wrong label is still a product bug.

## Scope

- First-job CapSequence 3a step copy in 6 locales.
- PremierEclairageCard test fixture semantics.
- Regression assertions for the French first-job 3a step and onboarding card.

## Non-goals

- Recomputing 3a tax savings.
- Changing CapSequence step IDs or routing.
- Rewriting the backend premier éclairage selector, which already uses
  `tax_saving_3a` for actual fiscal estimates.

## Implementation Plan

1. Sweep user-facing 3a strings for ceiling-as-tax-saving wording.
2. Rewrite first-job 3a step descriptions to say the amount is deductible.
3. Update the onboarding card fixture title so it matches its `7'258 CHF`
   ceiling value.
4. Add regression assertions blocking the old French wording.
5. Verify ARB parity, LSFin banned-term scan, accent lint, Flutter tests, and
   Flutter analysis.

## Acceptance Criteria

- No first-job 3a step says `7'258 CHF` is a tax saving.
- The onboarding fixture no longer normalizes `7'258 CHF` under an
  `économie 3a annuelle` title.
- Targeted tests guard the corrected semantics.
