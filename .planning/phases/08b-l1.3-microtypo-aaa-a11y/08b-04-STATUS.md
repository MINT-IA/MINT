# Phase 8b Plan 04: Live a11y Session — STATUS: DEFERRED

**Decision date:** 2026-04-08
**Decision maker:** Orchestrator (autonomous expert call)
**Fork selected:** Fork B — defer to Phase 12 ship gate

## Context

Plan 08b-04 scoped a ≥1 live accessibility test session with one of 3 partners (SBV-FSA, ASPEDAH, Caritas). The session feeds the AAA honesty gate decision: "AAA met on S0-S5" OR "descoped to AA per ACCESS-09".

## Blocker

ACCESS-01 recruitment emails tracked in `docs/ACCESSIBILITY_TEST_LAYER1.md` have NOT been sent yet as of Phase 8b execution window. The tracker skeleton exists (created Phase 1) but all 6 rows remain in PENDING state with no contact names, no send dates, no replies.

## Fork selected (3 options were B/A/C)

- **Fork A** (run session this phase) — BLOCKED: no email = no session.
- **Fork B — DEFER to Phase 12 ship gate — SELECTED.**
- **Fork C** (descope now to AA per ACCESS-09) — rejected: too early, AAA tokens are in place and the descope is a last-resort.

## Rationale for Fork B

Phase 12 success criterion 5 (ROADMAP line 231) already explicitly allows:
> "target 3 sessions across Phases 8b + 12 (full brief target). Acceptable descope: 2 sessions ONLY if a partner ghosted despite Phase 1 day-1 emails AND a written 'AAA descoped to AA + documented gaps' decision is committed per ACCESS-09."

Collapsing all 3 sessions into Phase 12's window is doctrine-compatible: the criterion allows it as long as the emails were sent at some point and the total count hits ≥2 by ship gate. By deferring to Phase 12, we keep Phase 8b closable now without blocking on an async human dependency.

## What Phase 8b delivered without Plan 04

- AAA tokens applied to all 6 S0-S5 surfaces (Plan 08b-01 green, 36 swaps)
- Spiekermann microtypo pass (Plan 08b-02 green, enforcement test + 4pt grid + heading levels ≤3 + Aesop headline demotion + MUJI 4-line)
- liveRegion on coach_message_bubble + reduced-motion fallbacks (Plan 08b-03 green, 5 new accessibility tests)

Three of the four ROADMAP §8b success criteria are met (items 1-4). Item 5 (live session) is deferred, not skipped.

## Action items carried to Phase 12

1. **ACCESS-01 email send must happen before Phase 12 execution.** Orchestrator should surface this as a Phase 12 prerequisite in the Phase 12 CONTEXT.md.
2. **Plan 12-XX must include a 3-session or 2-session-with-descope fork** matching Phase 12 success criterion 5 semantics.
3. **AAA honesty gate decision must be committed in Phase 12**, not Phase 8b.

## What closes Phase 8b (partial close, not full)

Phase 8b is marked **COMPLETE with deferral note**. Plans 01-03 fully green. Plan 04 absorbed by Phase 12 via doctrine-compatible fork. No blocker, no scope leak.
