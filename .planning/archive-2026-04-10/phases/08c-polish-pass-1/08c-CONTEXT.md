# Phase 8c — Polish Pass #1 · CONTEXT

**Phase:** 08c-polish-pass-1
**Date:** 2026-04-07
**Branch:** `feature/v2.2-p0a-code-unblockers`
**Mode:** Supervision-only (no code commits). Output = `docs/POLISH_PASS_1.md`.
**Depends on:** Phase 8a (MTC migration), Phase 8b (AAA + microtypo + liveRegion)
**Requirements touched:** AESTH-01, 02, 03, 05, 06, 07, STAB-20

## Why this file exists

Phase 8c has no separate planner — it is a single cross-surface review pass. This CONTEXT
file exists only to anchor the phase directory in the planning tree and to record the
scope decisions made at execution time.

## Scope (what is in / out)

**IN:**
- Read the 6 S0-S5 source files at current HEAD.
- Read available golden masters (`apps/mobile/test/goldens/masters/*.png`).
- Compare current state vs the Phase 3 `docs/AUDIT_RETRAIT_S0_S5.md` baseline.
- Audit cross-surface coherence on 4 axes: typography, spacing, color, motion.
- Produce a tagged delta proposal list (hot-fix-now / refine / defer).
- Flag any anti-shame regression against the 6 checkpoints in `feedback_anti_shame_situated_learning.md`.

**OUT:**
- ANY code edit (orchestrator brief: zero code touched, `git diff --stat HEAD~1 -- apps/mobile/lib/ services/backend/app/` must return empty after the commit).
- Julien sign-off (removed from touch budget per expert decision — Claude reviews goldens and reports).
- Running the app / emulator (goldens + static read are the evidence base).

## Deliverables

1. `docs/POLISH_PASS_1.md` — the 8-section delta report (executive summary → per-surface → cross-surface tables → element count delta → tagged proposals → visual benchmarks → anti-shame audit → conclusion).
2. `.planning/phases/08c-polish-pass-1/08c-SUMMARY.md` — phase close-out.
3. Single commit: `docs(p8c): Polish Pass #1 — cross-surface aesthetic delta report`.

## Success criteria (per ROADMAP §Phase 8c)

1. ✅ Per-surface screenshot diff captured where masters exist; gaps documented where they don't.
2. ✅ Cross-surface coherence audit: 4 tables (typography, spacing, color, motion).
3. ✅ Element count delta verified against Phase 3 baseline.
4. ✅ Delta proposal list tagged (hot-fix-now / refine-in-8b / defer-to-post-milestone), each with surface + file + one-line rationale.
5. ⏭️ Julien sign-off removed per orchestrator decision (T3 out of touch budget).

## Read manifest (what this phase actually consumed)

- `docs/AUDIT_RETRAIT_S0_S5.md` (Phase 3 baseline — the DELETE/KEEP/REPLACE ground truth)
- `.planning/phases/08a-l1.2b-mtc-11-surface-migration/08a-SUMMARY.md`
- `.planning/phases/08b-l1.3-microtypo-aaa-a11y/08b-SUMMARY.md`
- `apps/mobile/lib/screens/landing_screen.dart` (S0)
- `apps/mobile/lib/screens/onboarding/intent_screen.dart` (S1)
- `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` (S2)
- `apps/mobile/lib/widgets/coach/coach_message_bubble.dart` (S3)
- `apps/mobile/lib/widgets/coach/response_card_widget.dart` (S4)
- `apps/mobile/lib/widgets/report/debt_alert_banner.dart` (S5)
- `apps/mobile/lib/theme/colors.dart` (6 AAA tokens)
- `apps/mobile/test/goldens/masters/landing_*.png` (4 landing masters read visually)
- `apps/mobile/test/goldens/masters/mtc_*.png` (3 MTC masters read visually)
- `feedback_anti_shame_situated_learning.md` (doctrine ground truth)
- `feedback_vz_content_not_visual.md` (benchmark distinction)
