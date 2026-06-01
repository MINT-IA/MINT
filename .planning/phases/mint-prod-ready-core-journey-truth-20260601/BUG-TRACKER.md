---
description: Living production-readiness bug tracker for the MINT core journey truth mission.
status: draft
date: 2026-06-01
---

# Bug Tracker — Core Journey Truth

## Severity

- P0: breaks trust, navigation, persisted truth, or core money/profile journey.
- P1: confusing or risky but not blocking the primary journey.
- P2: polish or follow-up once core trust is stable.

## Open / Recently Closed

| ID | Severity | Journey | Area | Finding | Status | Release blocker | Owner | Evidence / Next proof |
|---|---|---|---|---|---|---|---|---|
| CJT-001 | P0 | Rapport synthesis | Rapport/navigation | Rapport was used as generic fallback and could be opened with wrong prefill shape. | verified | no | Codex | `99f2c4505`; route planner/screen registry tests; generated contracts |
| CJT-002 | P0 | Rapport synthesis | Rapport/design | Rapport first viewport still reads partly as a mini-dashboard, not a synthesis with one conclusion and next action. | open | yes | Product + UI | Needs redesign plan + screenshot/Maestro |
| CJT-003 | P0 | Money trust | Budget/Mon Argent/Rapport | Money truth has had multiple read models and fallback priorities. | in_progress | yes | Architect + Flutter | Existing money trust Maestro; map exact owners next |
| CJT-004 | P0 | Profile truth | Profile truth | save_fact/profile/sync/hydration has had coupled-field and spouse/single hazards. | in_progress | yes | Backend + Flutter | Commits `e3e632dba`, `901f06a73`; run profile truth map |
| CJT-005 | P0 | Human navigation | Navigation | Back behavior on Rapport forces `/coach/chat`, regardless of entry context. | open | yes | Flutter | Add test + fix after route-entry audit |
| CJT-006 | P1 | Compliance/copy | i18n/design system | `ThematicCard` status labels are hardcoded (`Serein`, `A renforcer`, `Alerte`). | open | no | Flutter/i18n | ARB parity required if touched |
| CJT-007 | P1 | QA evidence | Docs/tooling | AGENTS.md says `./tools/mint-routes check`, but CLI exposes `reconcile`, `health`, `redirects`, `purge-cache`. | open | no | DevEx | Update docs or add alias |
| CJT-008 | P1 | Scan to profile | Scan/profile | Document extraction may show data without proving profile persistence/recalculation in a journey. | open | no | OCR/Flutter | Audit scan pipeline + Maestro |
| CJT-009 | P1 | Human navigation | Coach context | Coach relevant-screens fill can include generic decision canvases if phase adaptation has few screens. | open | no | Coach/navigation | Audit ContextInjector surfaced routes |
| CJT-010 | P2 | Storytelling | Naming | User-facing concepts split between Plan/Rapport/Bilan/Synthese. | open | no | Product/i18n | Choose one concept, update ARB |
| CJT-011 | P0 | Coach trust | Coach/citations | Coach must answer one Swiss 3a/tax-style question with current cited numbers or refuse cleanly; no stale constants or generic key error. | open | yes | Backend + QA | Golden backend test + Maestro Coach flow |
| CJT-012 | P0 | Beta archetype gate | Product scope | Unsupported archetypes/life events need hard gates; beta scope is French `swiss_native` and `swiss_native_couple` first. | open | yes | Product + Coach | Supported-scope matrix + route/Coach tests |
| CJT-013 | P0 | Phase 02 substrate | Backend deploy | Event-log/fact-current deploy/cutover risk is not closed by local code alone. | open | yes | Backend/Release | Alembic chain, `fact_event`/`fact_current`, backfill x2, projection diff |
| CJT-014 | P1 | QA evidence | Evidence storage | QA screenshots/logs in `/tmp` are not durable enough for release audit. | open | no | QA | Store evidence under `.planning/_walker/` or phase folder |
| CJT-015 | P0 | Human navigation | Universal/deep links | Universal links/deep links need signed on-device evidence before release. | open | yes | Mobile/Release | Signed link proof or explicit release deferral |
| CJT-016 | P1 | QA evidence | Maestro/CI | Maestro regression set needs a documented PR/CI or repeatable local gate. | open | no | QA/DevEx | Command list + artifact convention |

## Rules For Closing A Bug

A bug can be marked `verified` only when the row has:

- commit SHA or file diff reference;
- exact test command or Maestro flow;
- if UI-facing, screenshot or simulator evidence;
- if copy-facing, i18n/accent/banned-term evidence.
- if release-blocking, a release decision: fixed, explicitly deferred, or blocking promotion.
