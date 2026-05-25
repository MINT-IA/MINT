description: Audit v0 of visible financial figures before adding trust chips.

# Money Trust Contract v1 — Figure Audit v0

## Purpose

Mint can be creative only if every visible number is boringly traceable. This
audit is the bridge between the current data-spine work and the future
trust-chip implementation.

Rule for the next code phase: do not add a new persistent money model. Add a
small display contract around existing producers first.

## Figure Classes

| Class | Meaning | Required trust fields |
|---|---|---|
| User fact | Directly entered/scanned value | source, last updated, confidence |
| Derived present | Deterministic calculation from user facts | producer, input facts, confidence floor |
| Regulatory constant | Swiss statutory/registry value | registry key, effective period |
| Estimate | Heuristic or incomplete calculation | explicit estimate label, assumptions |
| Projection | Future path from assumptions | scenario, horizon, assumptions, producer |
| LLM/narrative | Text generated or selected around a number | numeric producer ID or no number |

## Active Surfaces

| Surface | Visible figure | Current producer | Trust status | Next action |
|---|---|---|---|---|
| Mon Argent / Aujourd'hui | Libre mensuel | `DataSpineSnapshot.budget.present.monthlyFree` | Good source shape, confidence displayed | Add producer/source chip from `BudgetSnapshot` metadata when available |
| Mon Argent / Aujourd'hui | Patrimoine net | `PatrimoineAggregator.computeFromDataSpine` or `compute(profile)` | Partial source tracking exists in `PatrimoineField`; not displayed as a unified chip | Expose known/missing count and source summary as trust metadata |
| Mon Argent / Situation | Revenu brut, logement, LAMal, liquidités, investissements, dettes | `DataSpineSnapshot.situation` `SpineValue` | Strong: each value has confidence/freshness/source metadata | Reuse this as the first trust-chip implementation target |
| Mon Argent / Prevoyance | AVS, LPP, 3a | `DataSpineSnapshot.pillars` `PillarFact` | Strong: known/missing state exists | Add source/freshness label; avoid showing missing values as zero |
| Mon Argent / Futur | Cible, libre aujourd'hui, écart mensuel | `DataSpineSnapshot.trajectory` | Medium: producer is clear but assumptions are not visible | Add scenario/horizon/assumptions label before visual polish |
| Budget detail | Revenu, charges, futur, disponible | `BudgetProvider` / `BudgetSnapshot` | Medium-good after PR #673; formula proof exists | Collapse formula stays; add source chip for profile vs manual cache |
| Coach whisper | “verser X CHF en 3a” | `CoachWhisperService`: 25% of available cash | Weak: heuristic number can look like advice/calculation | Either remove CHF amount or label as “piste heuristique”; never call it tax saving |
| Coach narrative 3a deadline | “économiser ~X CHF” | `CoachNarrativeService`: margin × 28-30% estimate | Weak-medium: explicit estimate but hard-coded marginal rate | Route through structured 3a tax impact estimate or label assumption visibly |
| 3a simulator | Impact fiscal estimé | `RetirementTaxCalculator.estimate3aTaxImpact` | Good direction since Plan 44/50 | Make this the canonical 3a tax-impact producer |
| Coach reasoner 3a staggering | “économie de X CHF” | `RetirementTaxCalculator.capitalWithdrawalTax` delta | Medium: deterministic, but assumptions not surfaced in UI copy | Attach assumptions and producer to recommendation payload |
| Old coach widgets | Many local `_fmt` CHF literals | Individual widget-local formulas | Weak/unknown | Do not reuse for core journey until wired to data spine or calc core |

## P0/P1 Findings

### P0 — Narrator must not invent CHF values

Any coach text containing a CHF amount must either:

- cite a deterministic producer (`BudgetSnapshot`, `DataSpineSnapshot`,
  `RetirementTaxCalculator`, `ArbitrageEngine`), or
- explicitly mark the amount as a heuristic and avoid fiscal/advice wording.

The riskiest current paths are:

- `CoachWhisperService` 3a suggestion: `available * 0.25`;
- `CoachNarrativeService` 3a tax saving: `marge3a * 0.30`;
- old coach widgets with local calculations and hard-coded copy.

### P1 — Data spine has enough metadata, UI does not yet show it

`SpineValue`, `PillarFact`, and `PatrimoineField` already carry most of the
trust data needed. The first code slice should surface that metadata rather
than invent a new `MoneyFigure` store.

### P1 — Budget manual cache vs profile-derived budget must be visible

PR #673 fixed precedence, but the user cannot tell whether a budget figure
came from:

- completed profile;
- partial budget form;
- restored manual cache;
- estimate.

The next budget trust slice should expose that source without changing the
budget formula.

## Proposed First Code Slice

`money-trust-contract-v1-01-spine-trust-chip`

Scope under 300 LOC:

1. Add a tiny `FigureTrustChip` widget that accepts label + tone only.
2. Wire it only into Mon Argent situation rows and pillar rows, using existing
   `SpineValue.meta.confidence` and `PillarFact.state`.
3. Add widget tests that known/estimated/missing values render distinct chips.
4. Do not touch Budget or Coach in that PR.

Then:

`money-trust-contract-v1-02-coach-number-gate`

1. Remove or soften heuristic CHF in `CoachWhisperService`.
2. Route 3a deadline tax impact through `RetirementTaxCalculator.estimate3aTaxImpact`.
3. Add golden copy tests for “CHF amount with producer” vs “heuristic amount”.

## Non-Goals

- No arbitrage redesign yet.
- No new persistent data table.
- No backend migration.
- No global rewrite of old coach widgets in this slice.
