# Mint 2.0 First Experience Rente/Capital — Proposed Plan

Status: Proposed. Planning-only until explicit GO from Julien.

## Scope

Allowed before GO:
`.planning/phases/mint-2-0-first-experience-rente-capital/`.

Forbidden before GO:
`apps/`, `services/`, `tools/`, `docs/`, `.planning/ACTIVE_CONTEXT.md`,
`.planning/ACTIVE_CONTEXT.json`, `.planning/STATE.md`,
`.planning/ROADMAP.md`, `.planning/INDEX.md`.

## Slice Order

1. Contract before code.
2. Entry and three axes.
3. Rente/capital data readiness.
4. Rente/capital result provenance.
5. Dossier navigation and account handoff.
6. Simulator, iPhone 13 mini, and closeout evidence.

Only Slice 1 is planned here. Later slices require their own code-mapped plan
before implementation.

## Slice 1 Tasks

1. Consolidate canonical `CONTEXT.md`, `SPEC.md`, `PLAN.md`, `VERIFICATION.md`.
2. Preserve prefixed files as receipts, not guard targets.
3. Keep Mint 2.0 as `next_product_phase_context`.
4. Define eight synthetic archetypes and eight negative cases.
5. Define receipt requirements for future numbers.
6. Define signalétique-axis refusal rules.
7. End with GO request before router promotion or product code.

Exit criteria: no product code, no router file, no public-doc lint finding in
this directory, `git diff --check` passes, final report names open blockers.

## Slice 2 Preconditions

Before mobile code, write a new plan with exact files, reuse of
`/rente-vs-capital`, grep proof for route/calculator symbols, calculator-boundary
decision between `rente_vs_capital_calculator.dart` and
`financial_core/arbitrage_engine.dart`, feature flag or kill switch, widget
tests for three axes, negative tests for signalétique axes, dossier persistence
test, Maestro entry flow from clear state, and iPhone 13 mini proof.

## Proposed Decision

Remain `next_product_phase_context` after Slice 1. Ask Julien for GO before
promotion. After GO, update the four router files in one coherent commit.
