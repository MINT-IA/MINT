---
gsd_state_version: 1.0
milestone: v2.2
milestone_name: La Beauté de Mint
status: Defining requirements
stopped_at: v2.2 milestone initialized, expert challenge applied, awaiting requirements
last_updated: "2026-04-07T12:30:00.000Z"
last_activity: 2026-04-07 — Milestone v2.2 started (reset phase numbering)
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# GSD State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-07)

**Core value:** User opens MINT and within 3 minutes receives a personalized, surprising insight — then knows exactly what to do next.
**Current focus:** v2.2 La Beauté de Mint — defining requirements after expert challenge of brief v0.2.3

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-04-07 — Milestone v2.2 started

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Baseline (carried from v2.1):**

- Flutter tests: 8137 green
- Backend tests: 4755 green
- Total: 12'892 green
- flutter analyze lib/: 0 warnings
- backend ruff: 0 errors
- CI dev: green on all jobs

**v2.2 targets:**

- Galaxy A14 cold start: TBD baseline (Phase 0 deliverable)
- WCAG 2.1 AA on 5 surfaces touched: 100% bloquant
- WCAG 2.1 AAA on S1-S5: 100% cible
- Krippendorff α on voice cursor spec: ≥ 0.67 (weighted ordinal)
- 3 live accessibility test sessions minimum (1 malvoyant·e, 1 ADHD, 1 fr-L2)
- 0 phrases G3 routées N1/N2 (hard floor)
- 0 phrases sujets sensibles routées N4/N5 (hard floor)

## Accumulated Context

### Decisions (v2.2 specific — see PROJECT.md Key Decisions for full table)

- Phase numbering reset to 1 for v2.2 (--reset-phase-numbers)
- 5 Layer 1 surfaces immuables (S1-S5), pas de 6e
- VoiceCursorContract = Phase 0 deliverable, single source of truth
- MTC = single rendering layer everywhere (split L1.2a + L1.2b)
- i18n carve-out for regional microcopy (canton-scoped ARB namespaces)
- Galaxy A14 manuel par Julien this milestone (CI auto déféré v2.3)
- Krippendorff α≥0.67 weighted ordinal for spec validation, editorial review for iteration
- Précision horlogère cut from Layer 1, only MTC bloom remains as "mécanisme visible"

### Carryover from v2.1 (TestFlight gate)

- **STAB-17 manual tap-to-render walkthrough** by Julien on real device. Scaffold ready in `.planning/milestones/v2.1-phases/07-stabilisation-v2-0/AUDIT_TAP_RENDER.md`. Blocks TestFlight.
- 12 orphan GoRouter routes deferred to v3.0 (or opportunistic during L1.1 audit du retrait)
- ~65 NEEDS-VERIFY try/except blocks (best-effort, address opportunistically)
- 1 stale test in `chat_tool_dispatcher_test.dart` (asserts null, now returns `/rente-vs-capital`)

### Pending Todos

- Research decision (research enabled in config — choose research first or skip)
- Define REQUIREMENTS.md with REQ-IDs
- Spawn gsd-roadmapper to create v2.2 roadmap (reset to Phase 1)

### Blockers/Concerns

- STAB-17 manual gate is the only blocker on TestFlight, and it's a human-only task. Phase 0 of v2.2 must surface it as a top-of-list deliverable so it doesn't slip again.

## Session Continuity

Last session: 2026-04-07T12:30:00.000Z
Stopped at: PROJECT.md updated for v2.2 with expert challenge decisions baked in
Resume file: None
