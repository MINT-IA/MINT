---
gsd_state_version: 1.0
milestone: v2.2
milestone_name: La Beauté de Mint
status: Code-complete on feature branch, pending dev merge + human gates
stopped_at: 16-phase roadmap executed end-to-end on feature/v2.2-p0a-code-unblockers; 18/18 automated ship gates PASS at HEAD; 6 human gates pending
last_updated: "2026-04-08T16:30:00.000Z"
last_activity: 2026-04-08 — Pre-dev-merge cleanup sweep (SHIP_GATE regen, SemanticsService deprecation fix, patrol deferred doc, wording honesty pass, working-tree cleanup)
progress:
  total_phases: 16
  completed_phases: 14
  total_plans: 0
  completed_plans: 0
  percent: 88
---

# GSD State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-07)

**Core value:** User opens MINT and within 3 minutes receives a personalized, surprising insight — then knows exactly what to do next.
**Current focus:** v2.2 La Beauté de Mint — code-complete on `feature/v2.2-p0a-code-unblockers`, pending dev merge + 6 human gates.

## Current Position

Phase: 12 (L1.6c Ton UX + Ship Gate) — code-side CLOSED, Plan 12-06 awaits human gates
Plan: 12-06 (human-gated walkthroughs + ACCESS-01 + Krippendorff)
Status: Pre-dev-merge cleanup finished. Branch `feature/v2.2-p0a-code-unblockers` ~170 commits ahead of dev, not yet pushed, not yet merged.
Last activity: 2026-04-08 — Pre-dev-merge fixes (SHIP_GATE regen 17/18 → 18/18, a11y deprecation migration, patrol investigation deferred to v2.3, SUMMARY wording honesty pass, 9 untracked design-brief/audit docs committed)

Progress: [█████████░] ~88% (14 full phases + 2 partial: 8b, 11)

## Phase status (16 phases — 1, 1.5, 2, 3, 4, 5, 6, 7, 8a, 8b, 8c, 9, 10, 10.5-prep, 11, 12)

| # | Phase dir | Status | Notes |
|---|---|---|---|
| 1 | 01-p0a-code-unblockers | CODE-COMPLETE | SUMMARY present |
| 1.5 | 01.5-chiffre-choc-domain-rename | CODE-COMPLETE | SUMMARY present |
| 2 | 02-p0b-contracts-and-audits | CODE-COMPLETE | SUMMARY present (+ 02-01 sub) |
| 3 | 03-p3-audit-retrait | CODE-COMPLETE | per ROADMAP |
| 4 | 04-p4-mtc-component-s4-migration | CODE-COMPLETE | SUMMARY present |
| 5 | 05-l1.6a-voice-cursor-spec | CODE-COMPLETE | SUMMARY present (+ 05-02 sub) |
| 6 | 06-l1.4-voix-regionale | CODE-COMPLETE | SUMMARY present |
| 7 | 07-l1.7-landing-v2 | CODE-COMPLETE | SUMMARY present |
| 8a | 08a-l1.2b-mtc-11-surface-migration | CODE-COMPLETE | SUMMARY present |
| 8b | 08b-l1.3-microtypo-aaa-a11y | PARTIAL CODE-COMPLETE | 3/4 plans closed, Plan 08b-04 (live a11y session) deferred into Phase 12 per Fork B |
| 8c | 08c-polish-pass-1 | CODE-COMPLETE | SUMMARY + HOTFIX SUMMARY present |
| 9 | 09-l1.5-mint-alert-object | CODE-COMPLETE | SUMMARY present |
| 10 | 10-l1.8-onboarding-v2 | CODE-COMPLETE | SUMMARY present, 6/6 ROADMAP SC met |
| 10.5 | 10.5-friction-pass-1 | CODE-SIDE PREP DONE | Walkthrough T4 pending human |
| 11 | 11-l1.6b-phrase-rewrite-krippendorff | PARTIAL CODE-COMPLETE | 4/5 plans closed, Plan 11-02 (tester recruitment + α validation) deferred to Phase 12 window |
| 12 | 12-l1.6c-ton-ux-ship-gate | CODE-SIDE CLOSED | 5/6 plans + hotfix sweep landed; Plan 12-06 awaits human gates |

## Pending human gates (Plan 12-06)

| # | Gate | Owner | Status |
|---|---|---|---|
| T4 | Phase 10.5 friction walkthrough (Galaxy A14, ~30 min) | Julien | PENDING |
| T5 | STAB-18 tap-render walkthrough on A14 (~60 min) | Julien | PENDING |
| T6 | PERF-01..04 baseline capture (cold start, scroll, bloom, ~45 min) | Julien | PENDING |
| T7 | Final "ready for humans" sign-off (~20 min) | Julien | PENDING |
| H-ACCESS-01 | 6 a11y partner recruitment emails + live sessions | Julien / partners | PENDING |
| H-Krippendorff | 15 testers classify 50 phrases + α validation | Tester pool | PENDING |

## Ship gate status (automated, code-side)

**18/18 PASS at HEAD** — regenerated 2026-04-08 via `python3 tools/ship_gate/gate_matrix.py`.
See `docs/SHIP_GATE_v2.2.md`.

Gate 2 (full flutter test suite) previously failing on 21 PremierEclairageCard contract-drift failures from Phases 7/8c/12. Cleared by test-side hotfix (commits ~3392abb7 / a40669a3 / 34d4393f), zero production code touched.

## Branch state

- Branch: `feature/v2.2-p0a-code-unblockers`
- Ahead of dev: ~170 commits (168 original + cleanup-sweep commits from 2026-04-08)
- Pushed to remote: **NO**
- Merged to dev: **NO**
- Next step: orchestrator opens PR feature → dev after this cleanup report

## Performance Metrics

- Flutter tests: **9326 passing** / 8 skipped / 0 failed (at HEAD, via gate 2 run)
- Backend tests: **5246 passing** (at HEAD, via gate 3 run)
- Total: **14'572 green**
- `flutter analyze lib/`: 0 errors (info-level `prefer_const_constructors` noise only)
- Backend ruff: 0 errors
- Ship gate matrix: 18/18 PASS

## v2.2 targets (carried from original roadmap)

- Galaxy A14 cold start: `timeToFirstFrameMicros < 2500ms` (deliverable T6 — pending human)
- Scroll FPS on Aujourd'hui: median ≥ 55, p95 ≥ 50 (pending T6)
- MTC bloom: 0 dropped frames over 250ms (pending T6)
- WCAG 2.1 AA on every touched surface: 100% (gate 8 green)
- WCAG 2.1 AAA on S0-S5: gate 15 `s0_s5_aaa_only` green
- Krippendorff α on voice cursor spec: ≥ 0.67 overall + per-level N4 + per-level N5 (pending H-Krippendorff)
- Reverse-Krippendorff on generation: ≥ 70% N4 classification (runner ready, pending tester pool)
- 0 phrases G3 routées N1/N2 (hard floor — gated in ComplianceGuard)
- 0 phrases sujets sensibles routées N4/N5 (hard floor — gated in ComplianceGuard)
- 3 live accessibility sessions minimum (pending H-ACCESS-01)
- Screens-before-first-insight: 2 (down from 5, verified in Phase 10)

## Decisions (v2.2 — cumulative)

- Phase numbering reset to 1 (`--reset-phase-numbers`) at milestone start
- 16 phases derived from 10 chantiers + P0 two-phase split + 1.5 domain rename + 8c polish + 10.5 friction insert
- Phase 13 ship gate folded into Phase 12 for cleanliness
- L1.2b + L1.3 co-located in Phase 8 per SUMMARY §3 dependency note (same files)
- 2026-04-08 cleanup: `SemanticsService.announce` migrated to `sendAnnouncement` across trust+alert widgets; deprecation warnings cleared on touched files

## Carryover from v2.1 (TestFlight gate) — status

- **STAB-17 manual tap-to-render walkthrough** — tracked as T5 (pending)
- 12 orphan GoRouter routes: deferred to v3.0 (opportunistic triage happened in Phase 3)
- ~65 NEEDS-VERIFY try/except blocks: opportunistic, not gating
- 1 stale test in `chat_tool_dispatcher_test.dart`: tracked

## Pending Todos

- Orchestrator: open PR `feature/v2.2-p0a-code-unblockers` → `dev` after cleanup verification
- After dev merge: run human gates per Plan 12-06
- v2.3 QA track: resurrect 2 skipped patrol tests once CI emulator infra (QA-04/QA-05) exists — see `.planning/phases/12-l1.6c-ton-ux-ship-gate/12-PATROL-DEFERRED.md`

## Blockers/Concerns

- None code-side. All automated gates green.
- 6 human gates remain the only path to full v2.2 ship.

## Session Continuity

Last session: 2026-04-08T16:30:00.000Z
Stopped at: Pre-dev-merge cleanup complete — ready for dev PR
Resume file: `docs/PRE_DEV_MERGE_FIXES.md`
