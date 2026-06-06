# Persona-Flow Benchmark Seed Evidence

Date: 2026-06-06
Rows touched: Row 21, Row 22, Row 23, Row 29
Status: Quality OS method evidence only

## What Changed

MINT Quality OS now has a persona-flow benchmark framework:

- human guide: `persona-flow-benchmark.md`
- machine-readable seed: `persona-flow-benchmark.json`
- scorecard linkage: `quality-os-scorecard.json`

## Why This Exists

The user feedback on 2026-06-06 was direct: MINT still does not feel good
enough, flows can pass mechanically without giving useful guidance, and each
scenario should be compared against Swiss expert-grade expectations.

This evidence records the method layer. It does not claim that any persona-flow
has passed yet.

## Guardrails

- The benchmark is capped at 2 personas, 1 scenario each, 5 checkpoints per
  scenario for the seed wave.
- Service-level golden path tests can seed personas, but cannot count as full
  runtime proof.
- Missing runtime proof caps flow score at 5/10.
- Runtime proof without an expert-reference artifact caps flow score at 6/10.
- Wrong calculation caps flow score at 4/10.
- Product recommendation, brand recommendation, ISIN/ticker advice, return
  promise, read/write financial action, unsafe logging, or PII leak fails the
  benchmark at 0/10.
- Provider pages are market examples, not legal authority.
- Regulated-advice wording or provider-product prescription caps flow score at
  6/10 and must open a compliance bug.
- Compliance and privacy caps apply before averaging; a green runtime flow
  cannot override a FINMA/LSFin or privacy failure.
- Ungated guidance for an unsupported persona hard-fails release claims for
  that scenario.
- Missing BUG-TRACKER entry for a P0/P1 gap caps the flow score at 6/10.

## Current Decision

Use `sophie_housing_purchase` and `independent_no_lpp_income_reality` as the
seed benchmark candidates.

Sophie has an existing service-level golden path and a high-value housing
purchase scenario. The independent-no-LPP scenario has no canonical runtime
fixture yet; that absence is a product-quality gap because it is the strongest
counterexample to salary-only and employee-only assumptions.

## Remaining Work

- CJT-061 now proves the local Rapport calculation contract for
  independent/no-LPP 3a assumptions, so the scenario is no longer blocked by a
  known hidden `pillar3a_max` model error.
- Add the independent-no-LPP canonical runtime fixture.
- Create the first Maestro persona-flow benchmark run.
- Compare observed MINT guidance against sourced Swiss guidance expectations.
- Open BUG-TRACKER entries for every P0/P1 gap found.
- Keep Row 22 and Row 23 `PARTIAL` until their runtime and accessibility
  closure criteria are met.
