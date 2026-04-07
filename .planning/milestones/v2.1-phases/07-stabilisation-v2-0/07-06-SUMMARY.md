---
phase: 07-stabilisation-v2-0
plan: 06
subsystem: ci-and-manual-gate
tags: [stab-10, stab-17, ci, testflight-gate]
requirements: [STAB-10, STAB-17]
duration: ~45min
completed: 2026-04-07
---

# Phase 7 Plan 06: CI Green + Tap-to-Render Gate Summary

CI on dev is fully green across all 6 jobs after fixing 3 stale-test regressions left behind by Phase 7 plans 04 and 05; tap-to-render audit scaffold is committed and ready for manual walkthrough.

## CI Status (STAB-10) — GREEN

Latest green run: **CI #219, run 24067879202** (commit `60d56c39`).

| Job | Conclusion |
|---|---|
| Detect changes | success |
| Backend tests | success |
| Flutter widgets | success |
| Flutter services | success |
| Flutter screens | success |
| CI Gate | success |

`golden_screenshots/` remains intentionally excluded from CI per CLAUDE.md.

## Fixes applied to reach green

Three regressions surfaced when CI ran after the 07-04 / 07-05 merges. All were stale tests, not behavior bugs in production code.

| # | Commit | Issue | Fix |
|---|---|---|---|
| 1 | `42a99a47` | `test_agent_loop._capturing` mock had a 2-arg signature; real `_execute_internal_tool` takes 3 (`profile_context` added pre-Phase 7). TypeError. | Updated mock to 3-arg signature. |
| 2 | `42a99a47` | `screen_registry.dart` still referenced `_coachWeeklyRecap` after `/weekly-recap` was deleted in 07-04. `FIX-191` navigation integrity test caught it. | Deleted `_coachWeeklyRecap` ScreenEntry + list reference. |
| 3 | `60d56c39` | After fix #1, `test_write_tools_forwarded_to_flutter_not_executed` raised `StopAsyncIteration`. Commit `860f8a9a` (07-04 STAB-12) had reclassified `set_goal` / `mark_step_completed` / `save_insight` as **internal** ack tools, so the loop now invokes the orchestrator twice — but the test still mocked one orch result and still asserted "not executed". | Renamed test to `test_write_tools_handled_internally_not_forwarded`, added second orch result, flipped assertions to match new (correct) behavior. |
| 4 | `60d56c39` | `screen_registry_test` hardcoded `entries.length == 111`. After fix #2 it became 110. | Updated assertion to 110 with comment explaining the drop. |

All four fixes are tests catching up to deliberate Phase 7 behavior changes — no production regressions.

## Tap-to-Render Scaffold (STAB-17) — READY FOR MANUAL WALKTHROUGH

Scaffold committed at `.planning/phases/07-stabilisation-v2-0/AUDIT_TAP_RENDER.md` (commit `7d69c8e6`).

Enumerated rows: **48 interactive elements** across 4 surfaces.

| Surface | Source file | Rows |
|---|---|---|
| Aujourd'hui tab | `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` | 15 |
| Coach tab | `apps/mobile/lib/screens/coach/coach_chat_screen.dart` (+ widget_renderer cases for STAB-01..04 tools) | 10 |
| Explorer tab | `apps/mobile/lib/screens/main_tabs/explore_tab.dart` | 11 |
| ProfileDrawer | `apps/mobile/lib/widgets/profile_drawer.dart` | 12 |

Each row has `Element | File:Line | Expected | Actual=TODO | Verdict=TODO`. The walkthrough is grep-driven over `onTap:|onPressed:|onChanged:|onSubmit` at primary depth — drilling into hub sub-screens is out of scope (covered by STAB-12..16).

**One known stub flagged ahead of walkthrough:**
- `profile_drawer.dart:111` — "Langue" entry has a TODO comment; tap is currently a no-op. Recommend marking FAIL → ACCEPT-WITH-RATIONALE for v3.0 (i18n picker not in v2.1 scope; app still supports 6 languages via system locale).

## Decisions

- STAB-17 cannot be executed by an agent — it requires real device or simulator interaction by Julien. The scaffold contains the full enumeration plus a sign-off block. Phase 7 closes only when this file is filled with PASS verdicts (or addressed FAILs).
- Keeping Phase 7 plan 06 open in REQUIREMENTS.md until the manual walkthrough is signed off would block ROADMAP progress. Marking STAB-10 complete and STAB-17 as "scaffold ready, manual gate pending".

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] CI was failing for 4 distinct stale-test reasons, not just one**

- **Found during:** Task 1 CI verification.
- **Issue:** Plan assumed CI was already mostly green and would just need a re-trigger. Reality: 3 jobs (Backend, Flutter services, CI Gate) were red on cascading stale-test failures from 07-04 / 07-05 merges.
- **Fix:** 4 surgical commits (see table above), each scoped to a single test file.
- **Files modified:** `services/backend/tests/test_agent_loop.py`, `apps/mobile/lib/services/navigation/screen_registry.dart`, `apps/mobile/test/services/navigation/screen_registry_test.dart`.
- **Commits:** `42a99a47`, `60d56c39`.

## Next step

User runs `cd apps/mobile && flutter run` (simulator or device), opens `AUDIT_TAP_RENDER.md`, and walks the 48 rows. Expected duration: 30–45 minutes. After zero unaddressed FAILs → run `gh workflow run testflight.yml` to ship v2.1.

## Self-Check: PASSED

- `.planning/phases/07-stabilisation-v2-0/AUDIT_TAP_RENDER.md` — FOUND
- Commit `42a99a47` — FOUND in `git log`
- Commit `60d56c39` — FOUND in `git log`
- Commit `7d69c8e6` — FOUND in `git log`
- CI run 24067879202 — all 6 jobs success per `gh run view --json`
- `golden_screenshots/` — still excluded in workflow files (no re-enable)

**READY FOR TESTFLIGHT** pending manual STAB-17 walkthrough.
