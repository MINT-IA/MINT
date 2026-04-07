---
gsd_state_version: 1.0
milestone: v2.2
milestone_name: La Beauté de Mint
status: Roadmap created for v2.2
stopped_at: v2.2 roadmap written + expert-audit patched, 96/96 REQs mapped to 13 phases, awaiting /gsd-plan-phase 1
last_updated: "2026-04-07T13:30:00.000Z"
last_activity: 2026-04-07 — Roadmap created + expert-audit patched (13 phases, reset numbering)
progress:
  total_phases: 13
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# GSD State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-07)

**Core value:** User opens MINT and within 3 minutes receives a personalized, surprising insight — then knows exactly what to do next.
**Current focus:** v2.2 La Beauté de Mint — 12-phase roadmap created, ready for phase planning

## Current Position

Phase: 1 (P0a — Unblockers & Perf Baseline) — not started
Plan: —
Status: Roadmap created, awaiting `/gsd-plan-phase 1`
Last activity: 2026-04-07 — Roadmap created for v2.2 (13 phases, reset)

Progress: [░░░░░░░░░░] 0% (0/13 phases)

## Performance Metrics

**Baseline (carried from v2.1):**

- Flutter tests: 8137 green
- Backend tests: 4755 green
- Total: 12'892 green
- flutter analyze lib/: 0 warnings
- backend ruff: 0 errors
- CI dev: green on all jobs

**v2.2 targets:**

- Galaxy A14 cold start: `timeToFirstFrameMicros < 2500ms` (Phase 1 baseline deliverable)
- Scroll FPS on Aujourd'hui: median ≥ 55, p95 ≥ 50
- MTC bloom: 0 dropped frames over 250ms
- WCAG 2.1 AA on every touched surface: 100% bloquant CI (Phase 12 gate)
- WCAG 2.1 AAA on S0-S5: 100% cible (or documented AA descope per ACCESS-09)
- Krippendorff α on voice cursor spec: ≥ 0.67 overall + per-level N4 + per-level N5 (weighted ordinal)
- Reverse-Krippendorff on generation: ≥ 70% N4 classification
- 0 phrases G3 routées N1/N2 (hard floor)
- 0 phrases sujets sensibles routées N4/N5 (hard floor)
- 3 live accessibility sessions minimum (Phase 8 + Phase 12)
- Screens-before-first-insight: 2 (down from 5)

## Accumulated Context

### Roadmap shape (13 phases, reset numbering)

| # | Phase | Chantier | REQs |
|---|---|---|---|
| 1 | P0a Unblockers & Perf Baseline | STAB carryover + A14 baseline + a11y recruit | 9 |
| 2 | P0b Contracts & Audits | VoiceCursorContract + Profile field + AUDIT-01/02 | 8 |
| 3 | L1.1 Audit du Retrait | DELETE/KEEP list, -20% | 2 |
| 4 | L1.2a MTC Component + S4 | MintTrameConfiance v1, first consumer | 11 |
| 5 | L1.6a Voice Cursor Spec | Spec doc + 50 frozen phrases + narrator wall | 6 |
| 6 | L1.4 Voix Régionale | ARB carve-out + backend dual-system kill | 7 |
| 7 | L1.7 Landing v2 | S0 rebuild, Variante A | 6 |
| 8 | L1.2b + L1.3 Migration + Microtypo + AAA | 11-surface MTC migration + tokens + live a11y | 16 |
| 9 | L1.5 MintAlertObject | S5 typed API + G2/G3 grammar | 11 |
| 10 | L1.8 Onboarding v2 | Delete 5 screens, intent → chat | 11 |
| 11 | L1.6b Rewrite + Krippendorff | 30 phrases rewritten, α validation | 7 |
| 12 | L1.6c "Ton" + Ship Gate | User setting + all CI/manual gates green | 3 |

**Coverage:** 96/96 REQs mapped, 0 orphans, 0 duplicates.

### Critical path

**P0a (Phase 1) → P0b (Phase 2) → L1.6a (Phase 5) → L1.6b (Phase 11) → L1.6c (Phase 12)** is the longest chain. L1.6b is the bottleneck (Krippendorff validation + editorial review). Phase 1 is sequential gate; Phases 2-6 can overlap per the DAG in SUMMARY §6.

### Top 3 schedule risks (from PITFALLS.md top 10)

1. **P1 Tone-locking (CRITICAL)** — Claude may silently regress to polite register under N4/N5 instructions. Mitigated by Phase 5 (few-shot VOICE-07) + Phase 11 (reverse-Krippendorff VOICE-06). If Phase 11 reverse-test fails, system prompt rework pushes L1.6b by 3-5 days → L1.6c slips.
2. **P14 Live a11y tests start too late (HIGH)** — Recruitment lead time 2-4 weeks via SBV-FSA/ASPEDAH/Caritas. Phase 1 kicks off emails day 1 (ACCESS-01) but live sessions don't land until Phase 8. If recruitment slips past Phase 8, Phase 12 ship gate cannot meet the 3-session target and ACCESS-09 descope activates.
3. **P11 Regional validator recruitment (HIGH)** — 3 native validators (VS/ZH/TI) must sign off before Phase 6 merges. If any validator ghost, Phase 6 blocks, impacting Phase 11 regional phrase validation in 3 langs.

### Decisions (v2.2)

- Phase numbering reset to 1 (--reset-phase-numbers)
- 13 phases derived from 10 chantiers + P0 two-phase split
- Phase 13 ship gate folded into Phase 12 for cleanliness
- L1.2b + L1.3 co-located in Phase 8 per SUMMARY §3 dependency note (same files)

### Carryover from v2.1 (TestFlight gate)

- **STAB-17 manual tap-to-render walkthrough** → Phase 1 success criterion #1. Blocks TestFlight.
- 12 orphan GoRouter routes deferred to v3.0 (opportunistic during Phase 3 audit)
- ~65 NEEDS-VERIFY try/except blocks (opportunistic)
- 1 stale test in `chat_tool_dispatcher_test.dart`

### Pending Todos

- Run `/gsd-plan-phase 1` to decompose Phase 1 into plans
- Resolve Open Decision Gate #1 (VZ app teardown) before Phase 4 coding starts
- Resolve Open Decision Gate #2 (brand palette AAA sign-off) before Phase 8 merge

### Blockers/Concerns

- None at roadmap level. Phase 1 is self-contained and can start immediately.
- Recruitment lead time (P14) is the earliest time-bomb — Phase 1 must send emails on day 1.

## Session Continuity

Last session: 2026-04-07T13:00:00.000Z
Stopped at: ROADMAP.md written, REQUIREMENTS.md traceability filled, 96/96 mapped
Resume file: None — next step is `/gsd-plan-phase 1`
