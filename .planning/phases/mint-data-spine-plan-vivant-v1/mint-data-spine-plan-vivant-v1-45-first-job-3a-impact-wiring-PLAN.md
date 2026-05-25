# Plan 45 — First-job 3a impact wiring

## Problem

`FirstJobResult` still exposed only a legacy tax-saving number. Screens could
not inspect the deductible amount, marginal-rate estimate, or confidence.

## Scope

- Wire `FirstJobService` to `estimate3aTaxImpact`.
- Keep `economieFiscaleEstimee3a` for existing screen compatibility.
- Assert the result keeps ceiling and estimated saving separate.

## Non-goals

- Visual redesign of `FirstJobScreen`.
- Backend parity.

## Steps

1. Add failing `FirstJobResult.impactFiscal3a` test.
2. Add the structured field and feed it from `financial_core`.
3. Re-run first-job and tax tests plus analyzer.
