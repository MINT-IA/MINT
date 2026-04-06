---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Mint Système Vivant
status: defining_requirements
stopped_at: null
last_updated: "2026-04-06T12:00:00.000Z"
last_activity: "2026-04-06 — Milestone v2.0 started"
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# GSD State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-06)

**Core value:** User opens MINT and within 3 minutes receives a personalized, surprising insight — then knows exactly what to do next.
**Current focus:** Defining requirements for v2.0

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-04-06 — Milestone v2.0 started

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: —
- Total execution time: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

- Roadmap: 8 phases derived from 8 requirement categories; Cleanup (Phase 1) is a strict precondition
- Assembly milestone: ~500 lines of new code total; most components exist, 3 wires missing
- Phase 6 (Calculator Wiring) depends on Phase 2 only — can be planned after Phase 2 ships
- Codebase map: .planning/codebase/ (bootstrap snapshot — verify before acting)
- [Phase quick-260406-ey9]: Use 12% flat tax heuristic for RetirementBudget.monthlyTax
- [Phase quick-260406-ey9]: Make _computeMonteCarloAndTornado async with .then(setState) pattern

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 4 (Journey Maps): per-life-event step specification needed before planning (legal + product requirements for firstJob, housingPurchase)
- Phase 6 (Calculator Wiring): CoachProfile field → screen constructor parameter mapping needed before implementation
- flutter_animate ^4.5.0 version compatibility: verify with `flutter pub outdated` before adding to pubspec.yaml

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260406-dz8 | Register generate_financial_plan tool in coach_tools.py and wire widget_renderer.dart | 2026-04-06 | 23d84718 | [260406-dz8-register-generate-financial-plan-tool-in](./quick/260406-dz8-register-generate-financial-plan-tool-in/) |
| 260406-e7x | Add plannedContributions to JSON body in BackendCoachService and wire through backend pipeline | 2026-04-06 | 71080916 | [260406-e7x-add-plannedcontributions-to-json-body-in](./quick/260406-e7x-add-plannedcontributions-to-json-body-in/) |
| 260406-ees | Surface CapSequence journey steps on MintHomeScreen | 2026-04-06 | f2b3c4e6 | [260406-ees-surface-capsequence-journey-steps-on-min](./quick/260406-ees-surface-capsequence-journey-steps-on-min/) |
| 260406-en2 | Update MILESTONES.md and v1.0-MILESTONE-AUDIT.md: fix requirement count and status wording | 2026-04-06 | f6135b57 | [260406-en2-update-milestones-md-and-v1-0-milestone-](./quick/260406-en2-update-milestones-md-and-v1-0-milestone-/) |

## Session Continuity

Last session: 2026-04-06T08:55:05.534Z
Stopped at: Completed quick-260406-ey9-01-PLAN.md
Resume file: None
