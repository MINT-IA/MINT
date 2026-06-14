# Mint 2.0 First Experience Rente/Capital — Context

## Problem

The current first experience has failed the actual iPhone test several times:

- chat-first entry feels like a weak generic assistant, not Mint;
- account prompts arrive before value and frame account creation as the product;
- compliance edge cases appear too early for most Swiss users;
- controls can clip on iPhone 13 mini;
- counters and dossier snippets can collide visually;
- numbers can appear without a defensible chain from user data to calculator.

The root problem is not one broken screen. Mint lacks a first-experience contract that says which user question is live, which data is required, which numbers are allowed, and how the user can recover or navigate.

## Product Thesis

Mint is a Swiss financial dossier and navigation system.

The coach is not the product. The coach helps the user move through a dossier: questions asked, facts captured, calculations run, assumptions, missing pieces, saved answers, next actions, and documents to revisit later.

The first Mint 2.0 phase must prove one live door end to end:

**2e pilier : rente ou capital**

This door includes pre-retirement context when relevant, because it is often how Swiss advisory conversations start. It must not become a retirement-only app.

Two other doors are visible but not live calculators in this phase:

- **Logement : 2e / 3e pilier** — signalétique, explainer, notify/follow.
- **3a et rachats : impact fiscal** — signalétique, explainer, notify/follow.

The purpose of showing all three is orientation. The purpose of making only one live is quality.

## Current Decision

Three axes visible, one live door:

| Axis | Phase status | Allowed now | Refused now |
|---|---|---|---|
| `2e pilier : rente ou capital` | Live | data readiness, safe calculation, provenance, missing fields, navigation back to dossier | naked number, product recommendation, copied UI calculation |
| `Logement : 2e / 3e pilier` | Signalétique | education, saved interest, notify/follow, required-data preview | amount, simulation, hidden collection |
| `3a et rachats : impact fiscal` | Signalétique | education, saved interest, required-data preview | promised tax benefit, tax amount, tax-promise language |

## Non-Goals

- Do not rebuild the whole app in one phase.
- Do not produce a scenario encyclopedia as the deliverable.
- Do not hide poor navigation behind chat.
- Do not show any LPP, tax, mortgage, or replacement-rate number without provenance.
- Do not make FATCA / US tax status the second screen for the average Swiss path.
- Do not ask for birth date only because Apple does not provide it. Ask only when the live calculation needs age, and explain why.
- Do not make account creation the first value moment.

## Dossier Contract

A Mint dossier is the persistent, navigable artifact that replaces the "I had a good chat but cannot find the answer later" failure mode.

Minimum dossier sections for this phase:

- **Questions** — what the user asked or selected.
- **Facts** — canton, age/birth date when needed, employment/retirement context, household if relevant.
- **Readiness** — what is known, what is missing, what is optional.
- **Answers** — generated explanations tied to facts and calculator versions.
- **Calculations** — values or ranges with assumptions, sources, confidence/readiness, missing fields, version.
- **Next actions** — continue, save account, start over, exit, follow inactive axes.

The conversation can navigate this dossier and explain it. It must not become the only place where the dossier exists.

## Compliance and Calculation Boundary

Pre-account content is educational unless the required data and calculator provenance exist.

Required before a personalized amount:

- canton / tax residence when fiscal impact is involved;
- age or birth date when retirement/LPP timing is involved;
- household status when the calculation depends on it;
- relevant financial order of magnitude or user-provided figure;
- calculator source and version.

Canonical calculation rule:

- mobile `financial_core/` owns L1 single-number calculations;
- backend `services/backend/app/services/` owns L2-L4 compare/explain/invariant calculations;
- scenario/dossier/UI layers gate and render only.

## Existing Surface to Reuse

The live door is not a blank rebuild.

Existing code to inspect and reuse before Slice 2 implementation:

- `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart` — existing decision surface with `rente_vs_capital_screen` and `rente_vs_capital_disclaimer_card` semantics.
- `apps/mobile/lib/app.dart` — route `/rente-vs-capital` and legacy redirects.
- `apps/mobile/lib/routes/route_metadata.dart` — route metadata for `/rente-vs-capital`.
- `apps/mobile/lib/domain/rente_vs_capital_calculator.dart` — existing domain calculator that must be audited before further use.
- `apps/mobile/lib/services/financial_core/arbitrage_engine.dart` — `ArbitrageEngine.compareRenteVsCapital`, the financial-core path that must be checked against any domain calculator.
- `tools/simulator/flows/maestro-perfect-set/flow_row17_rente_vs_capital_disclaimer_runtime.yaml` and `flow_row17_rente_vs_capital_runtime_visual.yaml` — regression flows for the existing surface only.

Slice 2 should connect the new three-axis entry to the existing `/rente-vs-capital` surface after auditing the calculator boundary. It must not create a second rente/capital screen or calculator.

## Workflow Contract

Use [docs/MINT_AGENT_WORKFLOW.md](../../../docs/MINT_AGENT_WORKFLOW.md) as the operating workflow for this phase.

Claude or a specialist agent can write implementation. Codex reviews. Claude red-team reviews major docs or architecture. Engram records decisions and discoveries.

No product code starts until the state table and golden fixtures in this phase are reviewed.
