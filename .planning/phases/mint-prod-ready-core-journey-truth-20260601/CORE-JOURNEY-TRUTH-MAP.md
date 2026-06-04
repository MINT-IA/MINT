---
description: Living map of core MINT user journeys, their screen jobs, canonical data sources, duplicate risks, and verification gates.
status: draft
date: 2026-06-01
---

# Core Journey Truth Map

## Status Legend

- `open`: known work remains.
- `in_progress`: currently being fixed or audited.
- `verified`: deterministic evidence exists.
- `deferred`: deliberately postponed with rationale.

## Core Journeys

| Journey | Human promise | Primary surfaces | Canonical truth | Current risk | Priority | Status | Evidence |
|---|---|---|---|---|---|---|---|
| Profile truth | "MINT remembers my situation correctly." | Coach, Profile/Dossier, backend profile, sync | Backend profile + mobile hydrated CoachProfile/MintState | save_fact/profile/sync drift can corrupt or lose coupled fields | P0 | in_progress | Commits `e3e632dba`, `901f06a73`; further map needed |
| Money trust | "My money numbers are consistent." | Budget, Mon Argent, Rapport, Coach | BudgetSnapshot/DataSpine/BudgetProvider path must converge | Multiple budget read models and fallbacks | P0 | in_progress | Maestro money trust flow; commits `8e1aaecb5`, `2448d9724` |
| Rapport synthesis | "Show me what matters and what to do next." | Direct `/rapport`, legacy aliases `/report` and `/report/v2` redirect | Persisted report answers + canonical money/profile truth | Active UI is Bilan synthesis/export; risk now moves to keeping this role explicit in registry, tests, and runtime flows | P0 | verified | CJT-002/CJT-010 plus CJT-026 `ScreenBehavior.synthesisRecap`; direct `/rapport` runtime proof `evidence/maestro-ci/cjt-026-rapport-synthesis-recap-20260604T131746/`; Money Trust recheck `evidence/maestro-ci/cjt-026-money-trust-synthesis-recap-20260604T131846/` |
| Human navigation | "I always know where I am and why." | Shell, Coach route planner, route registry, deep links | ScreenRegistry + GoRouter + route_metadata | Legacy aliases, fallback routes, back behavior, orphaned entrypoints | P0 | open | `./tools/mint-routes check`; more route audit needed |
| Coach trust | "When Coach gives a number, it is current and cited." | Coach, backend tools, citation gate, regulatory constants | Backend tools + current Swiss constants + citation gate | Stale constants, generic errors, or uncited numbers destroy trust | P0 | open | Need cited 3a/tax answer flow or clean refusal |
| Beta archetype gate | "MINT only advises where it is competent." | Onboarding, profile, Coach, route planner | Supported archetype/life-event contract | Unsupported users can receive unsupported guidance if not gated | P0 | open | Need supported-scope matrix |
| Phase 02 substrate | "Persistent facts are deployable, auditable, and cut over." | Backend migrations, fact_event/fact_current, projections | Event log + current fact projection | Local code can pass while staging/prod cutover is unsafe | P0 | open | Need alembic/backfill/projection-diff evidence |
| Scan to profile | "Trusted documents improve my plan." | Scan, extraction review, Profile, projections | Confirmed extraction -> profile/provider/backend fact | Risk of extracted data showing but not persisting or not recalculating | P1 | open | AGENTS.md scan row; needs audit |
| Decision surfaces | "When I simulate, I understand a decision." | Explorer, simulators, Coach explanations | financial_core for L1, backend for L2-L4 | Screens may be technically correct but not linked to next action | P1 | open | needs screen-role audit |
| Compliance/copy | "MINT is clear and legally safe." | Coach, Rapport, education, action cards | ARB + compliance guard + citation gates | hardcoded labels, stale FR fallbacks, banned-term risk | P1 | open | ThematicCard status labels noted |
| QA evidence | "A future agent can audit every closure." | `.planning/`, Maestro logs, screenshots, test output | Persistent artifacts, not chat claims | `/tmp` screenshots/logs disappear and bug closure becomes unverifiable | P1 | open | Need evidence storage convention |

## First P0 Audit Table

| Item | Question | File family | Decision needed |
|---|---|---|---|
| DOB vs age | Do all flows store birth date/year, not only age? | profile models, CoachProfileProvider, backend profile | Canonical field and display policy |
| Budget available cash | Which object owns monthly free cash? | BudgetProvider, MintState, DataSpine, Rapport | Single read model and fallback priority |
| Rapport role | Is it "Synthese", "Plan", or "Bilan"? | ARB, FinancialReportScreenV2, route metadata | One concept across navigation and copy |
| Coach prefill | Which screens accept profile prefill and in what shape? | RoutePlanner, ScreenRegistry, app.dart | Per-screen input contract |
| Legacy routes | Which aliases are plumbing only? | app.dart, route_metadata, generated valid routes | Explicit non-routable alias policy |
| Back behavior | Does back return to human previous context? | screen app bars, GoRouter | Use pop when possible, fallback only when needed |
| 3a/tax Coach answer | Does Coach cite current Swiss data or refuse? | backend coach tools, citation gate, constants registry | One golden flow and no stale constants |
| Unsupported archetypes | Which profiles are beta-supported? | onboarding/profile, Coach, route planner | Gate unsupported cases with clear copy |
| Event-log cutover | Is Phase 02 deployable? | alembic, fact_event/current, projection scripts | Release blocker until deployment proof exists |
| Universal/deep links | Are signed links real on device? | route metadata, entitlements, Maestro/deep-link proof | Release blocker until signed evidence |

## Verification Matrix

| Gate | Required for P0 | Current note |
|---|---|---|
| Unit/widget tests | Yes | Must cover contract and absence of duplicates |
| `flutter analyze` | Yes | Run after Flutter edits |
| Backend tests | When backend touched | `ruff`/`pytest` per subsystem |
| Route parity | When routes/screen registry touched | `./tools/mint-routes check` |
| Maestro | Yes for journey-visible P0 | Prefer existing flows before adding new |
| Screenshot | Yes for design/storytelling changes | Direct simulator screenshot if flow already green |
| i18n parity | Any copy change | 6 ARB files, no hardcoded text |
| Backend deployment substrate | Yes before release | Alembic chain, backfill x2, projection diff |
| Compliance/citation | Yes for Coach claims/copy | Citation gate, banned terms, accent lint |

## Core Screen Role Contract

| Surface | Job | Production rule |
|---|---|---|
| Aujourd'hui | Attention and next action | No dense financial detail duplication |
| Mon Argent | Current financial state | Reads canonical money snapshot |
| Budget | Cashflow configuration/detail | Owns editable fixed-charge and envelope workflow |
| Coach | Conversation, explanation, routing | Numbers are cited/current or refused cleanly |
| Rapport / Bilan | Generated proof, synthesis, top decisions | Consumer only; `ScreenBehavior.synthesisRecap`; no independent P0 recalculation |
| Profile / Dossier | Facts, provenance, correction | Shows what MINT knows and lets user correct it |
| Scan | Trusted document ingestion | No silent profile mutation without review |
| Explorer | Secondary calculators/education | Not a global dashboard |
