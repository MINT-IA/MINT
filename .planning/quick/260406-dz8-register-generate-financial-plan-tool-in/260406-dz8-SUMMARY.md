---
phase: quick
plan: 260406-dz8
subsystem: coach-tools, widget-renderer
tags: [coach, tool-calling, plan-generation, flutter, backend]
dependency_graph:
  requires: []
  provides: [generate_financial_plan tool in COACH_TOOLS, PlanGenerationService wiring in widget_renderer]
  affects: [claude_coach_service.py tool dispatch, coach chat widget rendering]
tech_stack:
  added: []
  patterns: [fire-and-forget microtask for async Widget generation, T-04-04 calculator-first pattern]
key_files:
  created: []
  modified:
    - services/backend/app/services/coach/coach_tools.py
    - services/backend/tests/test_coach_tools.py
    - apps/mobile/lib/widgets/coach/widget_renderer.dart
decisions:
  - generate_financial_plan placed BEFORE generate_document (logical ordering: plan before document)
  - Fire-and-forget Future.microtask preserves synchronous Widget return contract
  - goal_general used as default goalCategory (caller provides intent, calculator picks approach)
metrics:
  duration: ~10 minutes
  completed: 2026-04-06T08:11:52Z
  tasks_completed: 2
  files_modified: 3
---

# Quick Task 260406-dz8: Register generate_financial_plan tool and wire Flutter renderer

**One-liner:** Backend COACH_TOOLS gains the `generate_financial_plan` tool (5 properties, required=[goal,narrative], write-category, Flutter-bound), and `widget_renderer._buildPlanPreviewCard` now triggers `PlanGenerationService.generate()` + `FinancialPlanProvider.setPlan()` when no persisted plan exists.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Register generate_financial_plan in backend COACH_TOOLS + tests | `5a22d23a` | coach_tools.py, test_coach_tools.py |
| 2 | Wire widget_renderer to PlanGenerationService + FinancialPlanProvider | `23d84718` | widget_renderer.dart |

## What Was Built

### Task 1 — Backend tool registration

Added `generate_financial_plan` entry to `COACH_TOOLS` in `services/backend/app/services/coach/coach_tools.py`:

- **5 properties:** `goal` (string, required), `narrative` (string, required), `monthly_amount` (number, optional), `milestones` (array, optional), `projected_outcome` (string, optional)
- **category:** `write`, **access_level:** `user_scoped`
- NOT added to `INTERNAL_TOOL_NAMES` — Flutter-bound, same pattern as `generate_document`
- Description explicitly states "computed by Flutter-side calculators, NOT by the LLM" (T-dz8-02 mitigation)

Added `TestGenerateFinancialPlanTool` class (10 tests) to `test_coach_tools.py`. All 48 tests pass.

### Task 2 — Flutter wiring

Updated `_buildPlanPreviewCard` in `apps/mobile/lib/widgets/coach/widget_renderer.dart`:

- Added `import 'package:mint_mobile/services/plan_generation_service.dart'`
- Path 1 (T-04-04, preserved): if `planProvider.hasPlan`, use calculator-backed plan from provider — only `narrative` may come from LLM params
- Path 2 (new): if no plan yet, reads `CoachProfileProvider.profile` → fires `PlanGenerationService.generate()` via `Future.microtask` (fire-and-forget) → persists via `planProvider.setPlan(plan)` → provider notifies listeners → chat rebuilds with real plan
- Path 3 (unchanged): fallback `PlanPreviewCard` shown while generation is in progress
- `flutter analyze lib/widgets/coach/widget_renderer.dart`: 0 errors

## Verification

```
Backend: 48/48 tests passed (python3 -m pytest tests/test_coach_tools.py -v)
Flutter: flutter analyze lib/widgets/coach/widget_renderer.dart → No issues found!
```

## Deviations from Plan

**1. [Rule 3 - Blocking] Restored deleted working-tree files**

- **Found during:** Pre-execution worktree setup
- **Issue:** The worktree's `git reset --soft` had left 788 files deleted in the working tree (including `plan_generation_service.dart`, `financial_plan_provider.dart`, `test_coach_tools.py`). These are tracked in git at HEAD but were missing from disk.
- **Fix:** Ran `git checkout HEAD -- .` to restore all working-tree files before starting implementation.
- **No code changes required** — files were already at the correct HEAD revision.

None in plan implementation — plan executed exactly as written after worktree restoration.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The `generate_financial_plan` tool is Flutter-bound (never executed server-side). T-dz8-01 and T-dz8-02 mitigations are in place as designed.

## Self-Check: PASSED

- FOUND: services/backend/app/services/coach/coach_tools.py
- FOUND: services/backend/tests/test_coach_tools.py
- FOUND: apps/mobile/lib/widgets/coach/widget_renderer.dart
- FOUND: commit 5a22d23a (Task 1)
- FOUND: commit 23d84718 (Task 2)
