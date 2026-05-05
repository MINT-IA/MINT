---
gsd_state_version: 1.0
milestone: v2.10
milestone_name: Le Premier Éclairage (Cleo-grade)
status: roadmap_complete
stopped_at: Roadmap defined 2026-05-04. 6 phases (70-75), 31/31 REQs mapped, ~11.5 days estimated effort. Hygiene + PR triage = first phase ; Walker E2E = last phase before TestFlight cut. PRs #478-#482 absorbed into Phase 70 (HYG-01) + Phase 71 (PR #480 + #482 validated behind new UI) + Phase 72 (PR #481 prompt-path). Next - /gsd-plan-phase 70.
last_updated: "2026-05-04T13:00:00.000Z"
last_activity: 2026-05-04
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# GSD State: MINT v2.10 — Le Premier Éclairage (Cleo-grade)

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-05)
See: .planning/ROADMAP.md (defined 2026-05-04)
See: .planning/REQUIREMENTS.md (traceability complete 2026-05-04)

**Core value:** Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, reçoit une réponse qui le surprend, crée un compte pour ne pas perdre ça, et revient.
**Current focus:** v2.10 milestone — roadmap complete, ready to plan Phase 70 (Hygiene + PR Triage + LSFin Lint).

## Constraints (from Julien — 2026-05-05)

- **No human tests.** Claude validates everything via simulator iPhone (Mac mini), walker E2E + tap-render diff vs mockup, BEFORE Julien sees anything.
- **Image budget.** Max 1-2 screenshots per checkpoint shown to Julien ; full gallery archived under `.planning/walker/<run-id>/`.
- **TestFlight = Claude validates first.** No human device gate. Replaced by automated 4-archetype walker pass.
- **No new PRs** outside the 6 v2.10 phases.

## v2.10 Phase Plan (6 phases, sequential)

| # | Phase | Goal | REQs | Effort |
|---|-------|------|------|--------|
| 70 | Hygiene + PR Triage + LSFin Lint | Clean tree, decide #478-#482 + Phase 56 #470/#472, lefthook blocking | 6 | 1.5d |
| 71 | Anonymous Chat Cleo-grade redesign | Kill 6 felt-pills, chat-first surface, single-question opener | 7 | 2.5d |
| 72 | Premier Éclairage rendering | Insight hero card + soft account-creation hint + ECL-03 prompt | 4 | 2.0d |
| 73 | Landing v3 éditorial | Mockup port (Fraunces, MINT wordmark, 14px CTA, cream BG) | 7 | 2.5d |
| 74 | Walker E2E + golden 4 archétypes | LAST GATE — walker pass on 4 archetypes, ≤4% diff | 6 | 2.0d |
| 75 | TestFlight 2.10.0 cut | IPA upload, run-id evidence, MILESTONES.md close-out | 1 | 1.0d |

**Total:** 6 phases, 31/31 REQs mapped (100% coverage), ~11.5 days solo-dev sequential.

## Critical Path

```
70 Hygiene → 71 Anonymous Chat → 72 Premier Éclairage → 73 Landing v3 → 74 Walker E2E → 75 TestFlight cut
```

Sequential, not parallel. One shippable PR per phase. Design panel BEFORE pushing screens (per memory `feedback_design_panel_before_push`). Walker is LAST gate before TestFlight.

## PRs Absorbed Into v2.10

| PR | Title | Phase absorption | Status |
|----|-------|------------------|--------|
| #478 | 401 breadcrumb (Sprint 0) | Phase 70 HYG-01 (decide merge / close) | In flight |
| #479 | Nav audit + P1 + P3 (3 sites redirect preserved) | Phase 70 HYG-01 ; unblocks Phase 73 LAND-07 | In flight |
| #480 | AnonymousChatPersistence service | Phase 71 ANON-06 (validated behind new UI) | Shipped, re-validated in 71 |
| #481 | anonymous_eclairage_prompt backend | Phase 72 ECL-03 (prompt-path assertion) | Shipped, re-validated in 72 |
| #482 | UX wiring + auth_provider migrate clear | Phase 71 ANON-07 (validated behind new UI) | Shipped, re-validated in 71 |
| #470 | Phase 56 tool census A | Phase 70 HYG-02 (decide merge or defer) | Pending decision |
| #472 | Phase 56 tool census B | Phase 70 HYG-02 (decide merge or defer) | Pending decision |

## Architecture Decisions (pre-phase v2.10)

- **Phase numbering**: 70-75 (not 33+ or 44+) — fresh-but-distinct namespace, avoid collision with v2.8 archived phases (32 + decimals) and v2.9 retired phases (40-43).
- **Sequential execution**: one shippable PR per phase, design panel pass per phase, no parallelization risk on screen-level files.
- **Walker LAST**: no TestFlight without 4-archetype walker green + ≤4% hero diff.
- **Hygiene FIRST**: LSFin lint must block pre-commit BEFORE chat copy edits in Phase 71 — anti-regression doctrine.
- **No new features**: 4 surfaces only (landing / anonymous_chat / insight render / register CTA exposed). All else deferred.
- **Single simulator target**: iPhone 17 only for v2.10 (per PROJECT.md). Documented fallback to iPhone 16 with widened tolerance if runtime unavailable.
- **No human device gate**: Claude validates on simulator. Replaces v2.7-style human walkthrough.

## Current Position

Phase: 70 (next to plan)
Plan: Not started
Status: Roadmap complete — ready for `/gsd-plan-phase 70`
Last activity: 2026-05-04
Next: `/gsd-plan-phase 70` to decompose Hygiene + PR Triage + LSFin Lint phase into ≤4 plans (pr-triage / state-alignment / arb-banned-terms-sweep / lefthook-wiring).

Progress: [░░░░░░░░░░] 0% (0/6 phases, 0/0 plans)

## Performance Metrics

**Velocity (from previous milestones):**

- v2.8 plans: 4-35 min/plan (5/9 phases shipped + 13 decimals before retire)
- v2.7 plans: 30-90 min/plan (compliance + encryption + Vision)
- v2.10 expected: design-heavy phases (71, 73) likely 30-60 min/plan ; release phases (70, 75) 5-15 min/plan ; integration (74) 60-90 min/plan

**v2.10 Execution Log:**

| Phase-Plan | Duration | Tasks | Files | Completed |
|------------|----------|-------|-------|-----------|
| (empty)    |          |       |       |           |

## Accumulated Context

### Decisions (v2.10 pre-phase, 2026-05-04)

- Phase numbering 70-75 chosen (fresh-but-distinct from v2.8 archived + v2.9 retired)
- 6 phases, sequential, ~11.5 days total estimate
- Hygiene + PR triage = Phase 70 (LSFin lint blocking pre-commit BEFORE chat copy edits in 71)
- Walker E2E = Phase 74 (LAST integration gate before TestFlight cut in 75)
- Design panel BEFORE pushing screens (per memory `feedback_design_panel_before_push`) for all UI phases (71, 73)
- HTML evidence report per phase (per memory `feedback_html_evidence_report`) under `.planning/phases/<phase>/<phase>-VERIFICATION-REPORT.html`
- ANON-05 mapped to Phase 72 (delivery is ECL concern, surface enabled by 71)
- ECL-04 mapped to Phase 71 (runtime check fires during chat ; static ARB lint in 70 is necessary-but-not-sufficient)
- HYG-05 alone in Phase 75 (TestFlight visibility only achievable post-walker-green)

### Blockers / Concerns (v2.10 entry)

- PRs #470 + #472 (Phase 56 tool census) — pending merge-or-defer decision in Phase 70 HYG-02. If rebase >30min, close-as-deferred.
- ARB sweep in Phase 70 may surface dozens of pre-existing LSFin violations across 6 ARBs — one-time sweep PR before lefthook activation.
- Fraunces italic rendering on iOS < 17 / Android low-end (R1 of Phase 73) — fallback chain documented.
- Visual diff oscillation around 4% threshold (R2 of Phase 74) — lock simulator runtime version, archive in summary.json.

### Known Good Foundations (to capitalize)

- PR #480 AnonymousChatPersistence already shipped — validated behind new UI in Phase 71
- PR #481 anonymous_eclairage_prompt already shipped — prompt-path asserted in Phase 72
- PR #482 clear() on register already shipped — validated behind new UI in Phase 71
- PR #479 nav audit + 3 sites redirect preserved — unblocks Phase 73 LAND-07
- PR #478 401 breadcrumb — observability for walker confidence in Phase 74
- v2.8 lefthook 2.1.5 already wired locally — only banned_terms_arb.py + no_legal_admission_in_public_docs.py to add in Phase 70
- v2.8 walker.sh foundation exists — Phase 74 extends with `--archetype` flag + 4-archetype batch runner
- MintColors design tokens (warmWhite, porcelaineHero) already defined — Phase 73 uses by reference (NEVER #2 no hardcoded colors)

## Session Continuity

Last session: 2026-05-04T13:00:00.000Z
Stopped at: ROADMAP.md defined (6 phases 70-75, 31/31 REQs mapped). REQUIREMENTS.md traceability complete. STATE.md frontmatter set to roadmap_complete. Ready for `/gsd-plan-phase 70`.
Resume file: None

---
*Last activity: 2026-05-04 — Roadmap defined, 31/31 REQs mapped, ready to plan Phase 70 (Hygiene + PR Triage + LSFin Lint).*
