description: Plan to align onboarding 3a tax-saving numbers with trust contract.

# Money Trust Contract v1-03 — Onboarding 3a Number Gate

## Goal

Stop the onboarding first-light 3a CHF figure from relying on local marginal
rate × ceiling shortcuts when assumptions are incomplete or invalid.

## Scope

1. Route mobile `MinimalProfileService.taxSaving3a` through
   `RetirementTaxCalculator.estimate3aTaxImpact`.
2. Suppress the tax-saving number when canton or salary cannot support a
   trustworthy estimate.
3. Make the `PremierEclairageSelector` tax-saving copy expose the estimated
   marginal-rate and canton assumptions.
4. Keep the tax-saving insight in pedagogical confidence mode because the
   marginal rate is estimated.
5. Align the backend onboarding service/selector with the same trust gate so
   `/onboarding/premier-eclairage` cannot bypass the mobile fix.
6. Add focused tests for valid, invalid-canton, zero-salary, selector-coherence,
   integration, and no-LPP cases.

## Non-Goals

No onboarding redesign, no new tax formula, and no notification copy rewrite.
