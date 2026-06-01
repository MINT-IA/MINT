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
| CJT-003 | P0 | Money trust | Budget/Mon Argent/Rapport | Money truth has had multiple read models and fallback priorities. | in_progress | yes | Architect + Flutter | Existing proof: `money-trust-contract-v1-27` Maestro exit 0 and `money-trust-contract-v1-40` Mon Argent flow exit 0; next proof is re-run `flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml` on this branch with evidence stored under this phase |
| CJT-004 | P0 | Profile truth | Profile truth | save_fact/profile/sync/hydration has had coupled-field and spouse/single hazards. | in_progress | yes | Backend + Flutter | Commits `e3e632dba`, `901f06a73`; next proof: profile truth map plus targeted backend/profile/provider tests |
| CJT-005 | P0 | Human navigation | Navigation | Back behavior on Rapport forces `/coach/chat`, regardless of entry context. | open | yes | Flutter | Add test + fix after route-entry audit |
| CJT-006 | P1 | Compliance/copy | i18n/design system | `ThematicCard` status labels are hardcoded (`Serein`, `A renforcer`, `Alerte`). | open | no | Flutter/i18n | ARB parity required if touched |
| CJT-007 | P1 | QA evidence | Docs/tooling | AGENTS.md says `./tools/mint-routes check`, but CLI exposes `reconcile`, `health`, `redirects`, `purge-cache`. | open | no | DevEx | Update docs or add alias |
| CJT-008 | P1 | Scan to profile | Scan/profile | Document extraction may show data without proving profile persistence/recalculation in a journey. | open | no | OCR/Flutter | Audit scan pipeline + Maestro |
| CJT-009 | P1 | Human navigation | Coach context | Coach relevant-screens fill can include generic decision canvases if phase adaptation has few screens. | open | no | Coach/navigation | Audit ContextInjector surfaced routes |
| CJT-010 | P2 | Storytelling | Naming | User-facing concepts split between Plan/Rapport/Bilan/Synthese. | open | no | Product/i18n | Choose one concept, update ARB |
| CJT-011 | P0 | Coach trust | Coach/citations | Coach must answer one Swiss 3a/tax-style question with current cited numbers or refuse cleanly; no stale constants or generic key error. | open | yes | Backend + QA | Contract proof passes: `evidence/coach-trust/pytest_anonymous_chat_tool_use_20260601.log` (`4 passed`). Runtime proof is red: `evidence/coach-trust/maestro-hero-20260601T232904/` reaches Coach composer, then hits waitlist after send; JUnit failure is `Encore en chantier pour ton profil` visible. |
| CJT-012 | P0 | Beta archetype gate | Product scope | Unsupported archetypes/life events need hard gates; beta scope is French `swiss_native` and `swiss_native_couple` first. | in_progress | yes | Product + Coach | Current contract proof: `evidence/archetype-gate/flutter_hard_gate_contracts_20260601.log` (`24 passed`); release proof still requires `flow_hardgate_expat_us.yaml` Maestro G1/G2 and staging/CI evidence |
| CJT-013 | P0 | Phase 02 substrate | Backend deploy | Event-log/fact-current deploy/cutover risk is not closed by local code alone. Phase 02 code-shipped, but operational cutover is still open. | open | yes | Backend/Release | Missing staging/prod alembic/table probes, backfill x2, projection diff, feature-flag state, PR-3b/PR-4/PR-5, SnapshotModel decommission, and final deploy report. Local head observed as `p123_waitlist_entry`; `projection_diff.py --audit-all-users` exits 2 because audit-all is stub-blocked. |
| CJT-014 | P1 | QA evidence | Evidence storage | QA screenshots/logs in `/tmp` are not durable enough for release audit. | open | no | QA | Wave 0 inventory identifies multiple historical `/tmp` citations; copy any re-run evidence under `.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/` |
| CJT-015 | P0 | Human navigation | Universal/deep links | Universal links/deep links need signed on-device evidence before release. | open | yes | Mobile/Release | `tools/simulator/flows/regression/_INDEX.md` marks `S004+F006+F007` as `OPEN-RELEASE-GATE`; needs signed TestFlight/real-device Universal Link proof or explicit release deferral |
| CJT-016 | P1 | QA evidence | Maestro/CI | Maestro regression set needs a documented PR/CI or repeatable local gate. | open | no | QA/DevEx | Regression index says `.github/workflows/maestro-regression.yml` is future/TBD; next proof is local command matrix plus CI decision |
| CJT-017 | P1 | Rapport export | Rapport/PDF | Rapport/PDF export proof is absent from the salvage closure trail. | open | no | QA/Product | Defer only if PDF export is out of beta scope; otherwise prove `generateFinancialReportPdf` with a current command/artifact. |
| CJT-018 | P1 | QA evidence | Maestro identifiers | Several Maestro flows rely on visible text/points because Flutter keys are not consistently exposed as iOS accessibility identifiers. | open | no | Flutter/QA | Current hero flow still needs point taps for intent, canton, revenue, scene, and `Creuser`; add semantics/accessibility IDs where product code owns stable buttons. |
| CJT-019 | P0 | Profile truth | Onboarding/profile gate | Runtime onboarding could seed a supported profile in memory after secure-store failure, then a later `loadFromWizard()` with empty persisted answers erased it, allowing Coach to redirect to waitlist after the composer was visible. | in_progress | yes | Flutter/Profile | Unit root-cause proof added in `test/providers/coach_profile_provider_secure_failure_test.dart`: `session-only onboarding profile survives a later wizard reload` failed before the provider marker fix and now passes. Runtime proof is not closed: rebuilt app no longer showed the legacy age-only screen, but Maestro/iOS automation is blocked before Coach by CJT-020. Previous red evidence remains `evidence/coach-trust/maestro-hero-20260601T232904/01.1-hero-04-coach-composer.png` + `01.1-hero-05-after-send.png`. |
| CJT-020 | P0 | QA evidence | Maestro/onboarding accessibility | Current onboarding controls are not reliably tappable by Maestro/iOS automation after the DOB/canton sequence: `Choisir ma date` required native AX/manual intervention, and the revenue `Continuer` button stayed visible/AX-enabled but did not activate through Maestro, AX label tap, logical coords, physical coords, or touch down/up. | open | yes | Flutter/QA | Evidence: rebuilt no-seed staging sim runs `evidence/coach-trust/maestro-hero-20260601T234919/`, `...T235105/`, `...T235233/`, `...T235404/`, `...T235608/`; all JUnit fail before `Où tu vis ?`/income progression. Manual screenshots show DOB current screen and revenue screen with visible enabled `Continuer`. Next proof: add stable semantics/accessibility identifiers or replace fragile widgets, then rerun `flow_hero_marge_fiscale_3a.yaml` to Coach send. |

## Rules For Closing A Bug

A bug can be marked `verified` only when the row has:

- commit SHA or file diff reference;
- exact test command or Maestro flow;
- if UI-facing, screenshot or simulator evidence;
- if copy-facing, i18n/accent/banned-term evidence.
- if release-blocking, a release decision: fixed, explicitly deferred, or blocking promotion.
