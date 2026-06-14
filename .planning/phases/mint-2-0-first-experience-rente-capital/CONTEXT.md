# Mint 2.0 First Experience Rente/Capital — Proposed Context

Status: Proposed. This phase stays `next_product_phase_context` until Julien
gives explicit GO and the router files are promoted together.

## Authority

Canonical files for future promotion: `CONTEXT.md`, `SPEC.md`, `PLAN.md`,
`VERIFICATION.md`. Earlier prefixed files in this directory are source receipts,
not future guard targets.

Consolidated source receipts:
`mint-2-0-first-experience-rente-capital-CONTEXT.md`, `PLANS.md`,
`STATE-TABLE.md`, `golden-onboarding-archetypes.md`,
`mint-2-0-first-experience-rente-capital-VERIFICATION.md`, `CLAUDE-REVIEW.md`.

## Product Frame

Mint is a Swiss financial dossier and navigation system. The coach explains and
routes; it does not replace the dossier.

Mint 2.0 first experience shows three axes and makes one live:

| Axis | Status | Allowed now | Refused now |
|---|---|---|---|
| `2e pilier : rente ou capital` | Live | readiness, missing fields, canonical calculation receipt, dossier entry | naked number, product ranking, copied UI calculation |
| `Logement : 2e / 3e pilier` | Signalétique | education, saved interest, notify/follow, required-data preview | amount, simulation, detailed unused collection |
| `3a et rachats : impact fiscal` | Signalétique | education, saved interest, missing-data preview | tax amount, tax promise, calculation without active fiscal engine and sources |

This is not a retirement app: 18-99, dossiers by life events, rente/capital as
one live door rather than the whole product.

## Dossier Minimum

Every answer must be retrievable outside chat:

- Questions: selected axis and user wording.
- Facts: age/birth date, canton, employment or retirement context, and financial
  range only when the next answer needs them.
- Readiness: known fields, missing required fields, optional fields.
- Answers: explanation tied to facts, assumptions, and calculator version.
- Calculations: value or range only with unit, sources, assumptions, readiness,
  missing fields, and version.
- Next actions: continue, save account after value, start over, exit, follow a
  signalétique axis.

## Calculation Boundary

Scenario/dossier/UI layers gate and render; they do not calculate.

- L1 single-number calculations: `apps/mobile/lib/services/financial_core/`.
- L2-L4 compare/explain/invariant calculations: `services/backend/app/services/`.
- Slice 2 must audit and reuse `/rente-vs-capital` instead of creating a second
  screen or calculator:
  `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart`,
  `apps/mobile/lib/domain/rente_vs_capital_calculator.dart`,
  `apps/mobile/lib/services/financial_core/arbitrage_engine.dart`,
  `apps/mobile/lib/app.dart`, `apps/mobile/lib/routes/route_metadata.dart`.

## Promotion Rule

Promotion requires explicit GO from Julien and one coherent update to
`.planning/ACTIVE_CONTEXT.md`, `.planning/ACTIVE_CONTEXT.json`,
`.planning/STATE.md`, and `.planning/ROADMAP.md`. That promotion must repoint
the router to these canonical files, including `CONTEXT.md`, not to the
prefixed source receipts.
