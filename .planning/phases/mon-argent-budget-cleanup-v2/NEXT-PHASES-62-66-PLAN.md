# Next Phases 62-66 — Canonical Situation Spine

## Expert Review Synthesis
- Product: budget/situation first, debt before optimisation, then liquidity/illiquidity, planning A-to-B, chat as navigator.
- Architecture: canonical read model is `DataSpineSnapshot.budget` / `BudgetSnapshot.present`, not `BudgetProvider`.
- QA: short Maestro flows should prove visible continuity after navigation/restart; unit/widget tests own math and storage.
- UX: Mon Argent and Budget need progressive disclosure over the existing spine, not another data layer.

## Phase 62 — Rapport Reads BudgetSnapshot
Scope:
- Render Rapport budget from a canonical `BudgetSnapshot.present` adapter when available.
- Keep `BudgetInputs` only as an internal migration fallback for tests/legacy entrypoints.
- Add a regression proving Rapport can render canonical budget values without reparsing raw answers.

Acceptance:
- Phase 61 partial-answer regression remains green.
- No new store/provider is introduced.

## Phase 63 — Budget Read Contract Guard
Scope:
- Add a grep/test guard documenting where runtime UI may still call `BudgetInputs.fromMap` or `BudgetService().computePlan`.
- Mark allowed migration sites explicitly.

Acceptance:
- Guard fails on new screen/widget direct parsing.

## Phase 64 — Debt-First Runtime QA
Scope:
- Add tests/flow specs for consumer debt priority and mortgage-only negative control.
- Ensure 3a/arbitrage copy is suppressed when debt protection is active.

Acceptance:
- Debt/surendettement is the first visible next action for material consumer debt.

## Phase 65 — Mon Argent IA Reset
Scope:
- Rework Mon Argent section model toward `Aujourd'hui`, `Budget`, `Patrimoine`, `Dette`, `Plans`.
- Default first viewport: one hero number, one situation map, one next action.

Acceptance:
- No duplicated financial calculations; view composition only over Data Spine/BudgetSnapshot.

## Phase 66 — Planning A-to-B Continuity
Scope:
- Surface trajectory status, target, monthly required, gap, and next lever consistently in Mon Argent and Coach.
- Add Maestro spec for on-track, drifting, blocked, and insufficient-data variants.

Acceptance:
- Coach explains/navigates the same plan shown by the UI; it does not rederive independent numbers.
