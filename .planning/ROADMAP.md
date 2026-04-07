# Roadmap: MINT

## Milestones

- ✅ **v1.0** — 8 phases (shipped before 2026-04)
- ✅ **v2.0 Mint Système Vivant** — 6 phases (shipped 2026-04-07) — see [milestones/v2.0-ROADMAP.md](milestones/v2.0-ROADMAP.md)
- 🚧 **v2.1 Stabilisation v2.0** — 1 phase (Phase 7) — in progress
- 📋 **v3.0** — TBD (start with `/gsd-new-milestone`)

## Phases

<details>
<summary>✅ v2.0 Mint Système Vivant (Phases 1-6) — SHIPPED 2026-04-07</summary>

- [x] Phase 1: Le Parcours Parfait (5/5 plans) — Léa golden path end-to-end
- [x] Phase 2: Intelligence Documentaire (4/4 plans) — Document capture → extraction → enrichment
- [x] Phase 3: Mémoire Narrative (4/4 plans, incl. gap closure) — Encrypted biography + anonymized coach
- [x] Phase 4: Moteur d'Anticipation (3/3 plans) — Rule-based proactive alerts
- [x] Phase 5: Interface Contextuelle (2/2 plans) — Smart Aujourd'hui cards
- [x] Phase 6: QA Profond (6/6 plans, incl. gap closure) — 9 personas, compliance, accessibility

**Total:** 24 plans, 47 tasks, ~530 tests added across 6 phases

**Audit status:** passed_with_tech_debt — see [milestones/v2.0-MILESTONE-AUDIT.md](milestones/v2.0-MILESTONE-AUDIT.md)

</details>

### 🚧 v2.1 Stabilisation v2.0 (Phase 7)

- [ ] **Phase 7: Stabilisation v2.0** — Close coach tool-call choreography end-to-end, run the 6-axis façade-sans-câblage audit, refresh Phase 1 tests, clean lints, bring CI green.

## Phase Details

### Phase 7: Stabilisation v2.0
**Goal**: v2.0 is provably wired end-to-end and ready for TestFlight — every coach tool reaches the user, every façade-without-wiring blind spot is audited and resolved, CI is green, lints are clean.
**Depends on**: v2.0 (Phases 1-6 shipped)
**Requirements**: STAB-01, STAB-02, STAB-03, STAB-04, STAB-05, STAB-06, STAB-07, STAB-08, STAB-09, STAB-10, STAB-11, STAB-12, STAB-13, STAB-14, STAB-15, STAB-16, STAB-17
**Success Criteria** (what must be TRUE):
  1. All 4 coach tools (`route_to_screen`, `generate_document`, `generate_financial_plan`, `record_check_in`) render user-visible widgets in `CoachMessageBubble`, verified by an end-to-end test that exercises tool call → orchestrator dispatch → renderer → visible bubble for each tool.
  2. All 6 façade-sans-câblage audit reports exist under `.planning/phases/07-*/` (`AUDIT_COACH_WIRING.md`, `AUDIT_DEAD_CODE.md`, `AUDIT_ORPHAN_ROUTES.md`, `AUDIT_CONTRACT_DRIFT.md`, `AUDIT_SWALLOWED_ERRORS.md`, `AUDIT_TAP_RENDER.md`) and every BROKEN/MISSING finding is either fixed in this phase or carries an explicit written accept with rationale.
  3. CI on `dev` branch is green on every job (Backend, Flutter widgets shard, Flutter services shard, Flutter screens shard, CI Gate); `golden_screenshots/` remains intentionally excluded.
  4. Backend `ruff` reports zero errors and `flutter analyze` reports zero warnings on `lib/` (test/style infos in `test/` acceptable).
  5. `AUDIT_TAP_RENDER.md` documents every interactive element on the 3 tabs (Aujourd'hui, Coach, Explorer) plus ProfileDrawer with an explicit PASS or FAIL verdict, expected outcome, and actual outcome — and zero FAIL entries remain unaddressed.
**Plans**: 6 plans
- [x] 07-01-PLAN.md — Façade audit (5 mechanical audits, parallelizable) — STAB-12..16
- [ ] 07-02-PLAN.md — Coach tool wiring + E2E test — STAB-01..04, STAB-11
- [ ] 07-03-PLAN.md — Phase 1 test refresh + IntentScreen async-gap fix — STAB-05..07
- [ ] 07-04-PLAN.md — Audit fix sweep — STAB-12..16 fix actions
- [ ] 07-05-PLAN.md — Lint & hygiene (ruff + flutter analyze) — STAB-08..09
- [ ] 07-06-PLAN.md — CI green + tap-to-render gate — STAB-10, STAB-17
**UI hint**: yes

### 📋 v3.0 (Planned)

Start with `/gsd-new-milestone` to define the next milestone.

## Progress

| Phase | Milestone | Plans | Status | Completed |
|-------|-----------|-------|--------|-----------|
| 1. Le Parcours Parfait | v2.0 | 5/5 | Complete | 2026-04-06 |
| 2. Intelligence Documentaire | v2.0 | 4/4 | Complete | 2026-04-06 |
| 3. Mémoire Narrative | v2.0 | 4/4 | Complete | 2026-04-06 |
| 4. Moteur d'Anticipation | v2.0 | 3/3 | Complete | 2026-04-06 |
| 5. Interface Contextuelle | v2.0 | 2/2 | Complete | 2026-04-06 |
| 6. QA Profond | v2.0 | 6/6 | Complete | 2026-04-07 |
| 7. Stabilisation v2.0 | v2.1 | 0/0 | Not started | - |
