---
gsd_state_version: 1.0
milestone: v2.14
milestone_name: Living MINT
status: julien-action-blocked
stopped_at: Autonomous run shipped 11/11 disposable plans across Phases 91-95 + partial 96/97. Phases 91/92/93/94/95 ✅ FULLY CLOSED. Phase 96 ✅ OBS-03 (Sentry tags) shipped (32121f23) ; OBS-01 + OBS-02 require Julien-action (Slack channel, Sentry alert UI, Checkly account, env secrets). Phase 97 ✅ SHIP-03 Control Matrix shipped (8da43a46, coverage 1.00) + SHIP-04 Counsel brief scaffolded (6fd460ac) ; SHIP-01 (Maestro) + SHIP-02 (TestFlight cohort) + SHIP-04 final sign-off PDF require Julien-action (counsel selection + 5 tester recruitment + NDA + App Store Connect). 22 commits on feat/phase-A-e2e-unblock, NOT pushed. Awaiting Julien checkpoint review.
last_updated: "2026-05-07T00:00:00.000Z"
last_activity: 2026-05-07
progress:
  total_phases: 7
  completed_phases: 5
  total_plans: 18
  completed_plans: 16
  percent: 78
---

# GSD State: MINT v2.14 — Living MINT

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-05-06)

**Core value:** Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, reçoit une réponse qui le surprend, crée un compte pour ne pas perdre ça, et revient chaque mois parce que MINT sait des choses que personne d'autre ne sait sur sa vie financière.

**Current focus:** Defining requirements → roadmap drafted → awaiting `/gsd-plan-phase 91`.

**Milestone goal:** Transformer MINT d'un prototype « shipped en code, théâtre en validation » en un MVP qui se walke bout-en-bout sans crash, qui rend personnalisé pour 3 archétypes (julien_swiss / lauren_expat_us / sofia_ticino), qui se sent vivant per Cleo benchmark, et qui passe l'inspecteur FINMA test.

## Architecture Decisions (pre-phase, v2.14)

- **Walker hits Railway staging LIVE** — replay-cache fixtures dead per doctrine 2026-05-06. Real LLM nightly, $22/mo Anthropic budget capped.
- **Author-and-grade-same-session = banned** — fixture and assertion never written by the same agent in the same session. Closes the 5-month theater identified by 7-expert panel.
- **Authority laundering = banned** — citations must point to existing decision files. No more references to phantom 2026-05-05 panel.
- **Tests pass ≠ product correct** — promptfoo + Pact + alembic check + testcontainers-Postgres + Sentry release-health = the new « tested ».
- **5 testers TestFlight Internal NDA cohort = ship gate** — closed Swiss-FR cohort with banner « pré-conformité, données non recommandées ». No journalist-defensible launch without 24h crash-free ≥ 99.5%.
- **Phase numbering continued from 90** — v2.13 closed at Phase A5 (Phase 90). v2.14 starts at Phase 91. Continuity > restart.
- **Dependency order over feature grouping** — critical-bugs (P0) first, ship gate last. Each phase is shippable on its own (dev → staging → testflight independently).
- **Solo founder + Claude horizon ≈ 3 weeks** — 7 phases × 2-4 days each. No bundle of a year's work into « Phase 91 ».
- **Design panel BEFORE pushing screens** — every Flutter screen create / revise / refactor → 4-person panel (UX + a11y + adversarial + engineering wiring) FIRST.
- **HTML evidence report per phase** — `.planning/phases/<phase>/<phase>-VERIFICATION-REPORT.html` cumulative, never `/tmp/`.
- **App targets Railway staging always** — mobile/sim/walker MUST hit `mint-staging.up.railway.app`, never local backend.
- **TestFlight ship path** — pubspec bump + dev→staging merge fires `testflight.yml`. Walker is OPTIONAL quality-gate, NOT ship blocker.

## Current Position

Phase: 91
Plan: Not started
Status: Defining requirements — roadmap drafted, traceability filled, awaiting `/gsd-plan-phase 91`
Last activity: 2026-05-06
Next: `/gsd-plan-phase 91` to decompose Phase 91 (Vivant Proactive Primitives) into executable plans. Then sequentially 92 → 97.

Progress: [░░░░░░░░░░] 0% (0/7 phases, 0/0 plans)

## Build Order

```
91 → 92 → 93 → 94 → 95 → 96 → 97
```

- **91 Vivant Proactive Primitives** (3-4j) — VIVANT-01..04 — closes BUG #5 P0, Cleo parity
- **92 Documents Vault Typed Wiring** (2-3j) — DOCS-01..03 — closes BUG #4 P0
- **93 Compliance Hardening — Audit Log + FATCA + Confidence** (3-4j) — COMP-01/03/04 — closes BUG #18/21/22
- **94 Compliance Polish — Locale + i18n + Constants** (1-2j) — COMP-02/05/06 — closes BUG #20/12/23
- **95 Test Infrastructure Réelle** (4j) — TEST-01..05 — closes test theater per doctrine W2
- **96 Production Observability** (2j) — OBS-01..03 — doctrine W4
- **97 MVP Ship Gate** (3-4j) — SHIP-01..04 — actual ship

**Total estimate:** 18-23 days solo-dev. ~3-week horizon. Sequential execution (no parallel plans, lesson from cascading agent damage).

## Phase Budget Table

| Phase | Name | Budget | Borrowable | REQs | Kill gate |
|-------|------|--------|------------|------|-----------|
| 91 | Vivant Proactive Primitives | 3-4j | — | 4 | BUG #5 P0 fix verified on device |
| 92 | Documents Vault Typed Wiring | 2-3j | — | 3 | BUG #4 P0 fix verified on device |
| 93 | Compliance Hardening | 3-4j | — | 3 | Audit log table migrated + FATCA test green |
| 94 | Compliance Polish | 1-2j | — | 3 | ARB parity 6-langs preserved |
| 95 | Test Infrastructure Réelle | 4j | — | 5 | promptfoo merge-blocking + alembic check green |
| 96 | Production Observability | 2j | — | 3 | Sentry alert fires on test crash |
| **97** | **MVP Ship Gate** | **3-4j** | **never** | **4** | **5 testers 24h ≥ 99.5% crash-free + counsel sign-off** |

## Performance Metrics

(Filled per-phase as plans execute.)

| Phase | Walker green | promptfoo pass-rate | Sentry crash-free | Maestro suite | Counsel sign-off |
|-------|--------------|---------------------|-------------------|---------------|------------------|
| 91 | — | — | — | — | — |
| 92 | — | — | — | — | — |
| 93 | — | — | — | — | — |
| 94 | — | — | — | — | — |
| 95 | — | ≥ 90% target | — | — | — |
| 96 | — | — | ≥ 99.5% target | — | — |
| 97 | — | ≥ 90% | ≥ 99.5% | green 3 devices | filed |

## Accumulated Context

### Decisions (decided pre-execution)

- 2026-05-06 — **Live-only walker, kill replay-cache** (option 1 from doctrine §6) ; cost ~$22/mo Anthropic ; defensible to FINMA, journalists, testers.
- 2026-05-06 — **Phase 91 first, not Phase 92** ; proactive push (VIVANT-01) is THE highest leverage per Cleo benchmark, even though DOCS-01 is also P0. Both are critical-bugs but proactive push unlocks the « living » feel that hooks users.
- 2026-05-06 — **7 phases, not 8 or 6** ; splitting compliance into hardening (P0/P1) + polish (P2/P3) keeps each phase atomic and shippable.
- 2026-05-06 — **No Maestro suite cross-phase** ; each phase ships its own walker/Maestro evidence ; the full E2E suite assembles at Phase 97 ship gate.

### Open Todos (pre-phase)

- [ ] Confirm Anthropic API budget cap mechanism on Railway (avoid $200-500/mo runaway per doctrine counter-argument).
- [ ] Confirm Maestro Cloud account active ($99/mo per doctrine §8 stack).
- [ ] Confirm Pestalozzi / Lenz & Staehelin / Vischer counsel availability for Phase 97 (1h paid review, CHF 800-1'200).
- [ ] Schedule 5 Swiss-FR friends for TestFlight Internal NDA cohort (Phase 97).

### Known Blockers (pre-phase)

- None at roadmap-draft time. All 25 requirements mapped, dependency order clear, doctrine locked.

## Session Continuity

### Last Session (2026-05-06 evening)

- 7-expert panel synthesized test-theater post-mortem doctrine.
- Doctrine artefact written: `.planning/decisions/2026-05-06-test-theater-post-mortem-doctrine.md`.
- MILESTONE-MVP.md + MILESTONE-MVP-PERIMETER.md drafted (architecture + 7 must-haves).
- USER_WALKTHROUGH_2026-05-06.md captured 23 bugs ; 13 fixed in same session ; 10 deferred to v2.14.
- gsd-new-milestone bootstrapped v2.14 ; gsd-roadmapper now writing Phases 91-97.

### Next Session

- `/gsd-plan-phase 91` to decompose Phase 91 (Vivant Proactive Primitives) into 3-5 executable plans.
- Expected first plan: « 91-01 ProactiveTriggerService wiring + 6 trigger types + flutter_local_notifications platform setup ».

---

*Last updated: 2026-05-06 — gsd-roadmapper agent close-out, Phases 91-97 drafted, 25/25 requirements mapped, status « Defining requirements » → ready for `/gsd-plan-phase 91`.*
