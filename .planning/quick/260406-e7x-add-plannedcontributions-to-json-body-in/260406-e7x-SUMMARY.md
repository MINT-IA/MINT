---
phase: quick-260406-e7x
plan: "01"
subsystem: coach-pipeline
tags: [flutter, backend, coach, planned-contributions, security]
dependency_graph:
  requires: []
  provides: [planned_contributions in CoachContext for system prompt rendering]
  affects: [backend_coach_service.dart, coach_chat.py, coach_context_builder.py]
tech_stack:
  added: []
  patterns: [list-of-dict injection sanitization, Optional[List[dict]] Python 3.9 compat]
key_files:
  created: []
  modified:
    - apps/mobile/lib/services/backend_coach_service.dart
    - services/backend/app/api/v1/endpoints/coach_chat.py
    - services/backend/app/services/coach/coach_context_builder.py
decisions:
  - Used snake_case key planned_contributions (not camelCase) in Flutter body map to match backend whitelist
  - Used Optional[List[dict]] instead of list | None for Python 3.9 compatibility
metrics:
  duration: ~10 minutes
  completed: "2026-04-06T08:20:00Z"
---

# Quick Task 260406-e7x: plannedContributions wired through coach pipeline

**One-liner:** Flutter serializes CoachProfile.plannedContributions as List<Map> and backend whitelists, sanitizes, and forwards them to CoachContext for system prompt rendering.

## What Was Done

Wired `plannedContributions` from `CoachProfile` (Flutter) through the entire backend coach chat pipeline so Claude has visibility into the user's planned monthly contributions (3a, LPP buyback, free savings, investments) during coaching conversations.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Serialize plannedContributions in Flutter chat() JSON body | 6907efc8 |
| 2 | Whitelist + sanitize planned_contributions; wire through build_coach_context | 71080916 |

## Changes Made

### apps/mobile/lib/services/backend_coach_service.dart
- Added `planned_contributions` key to HTTP POST body in `BackendCoachService.chat()`
- Serializes `profile.plannedContributions` as `List<Map>` with `id`, `label`, `amount`, `category` (excludes `isAutomatic` — not needed by coach)
- Uses snake_case key to match backend whitelist

### services/backend/app/api/v1/endpoints/coach_chat.py
- Added `"planned_contributions"` to `_PROFILE_SAFE_FIELDS` set
- Added list-of-dict injection sanitization in `_sanitize_profile_context()`: iterates each dict item and applies `_INJECTION_PATTERNS` to string values (mitigates T-e7x-01 and T-e7x-03)

### services/backend/app/services/coach/coach_context_builder.py
- Added `planned_contributions: Optional[List[dict]] = None` parameter to `build_coach_context()`
- Passes `planned_contributions or []` to `CoachContext` constructor
- Added `Optional[List[dict]]` import for Python 3.9 compatibility (replaced `list | None` union syntax)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Python 3.9 type union syntax**
- **Found during:** Task 2 — pytest import error
- **Issue:** Plan used `list | None` syntax which requires Python 3.10+; project runs Python 3.9
- **Fix:** Changed to `Optional[List[dict]]` with `from typing import List, Optional`
- **Files modified:** services/backend/app/services/coach/coach_context_builder.py
- **Commit:** 71080916

## Verification

- `flutter analyze lib/services/backend_coach_service.dart`: pre-existing error in `RetirementBudget.monthlyFree` (unrelated to this task, confirmed pre-existed before changes)
- Backend tests: 131 coach-specific tests passed; 4907 total passed (1 pre-existing compliance wording failure in `simulation_widgets.dart`, unrelated to this task)
- Grep confirms `planned_contributions` present in all 3 files

## Known Stubs

None — data flows end-to-end: Flutter serializes -> backend whitelists -> `_build_coach_context_from_profile` passes as kwarg -> `build_coach_context` accepts -> `CoachContext.planned_contributions` populated -> `claude_coach_service.py` renders in system prompt.

## Threat Surface

Threats T-e7x-01 and T-e7x-03 (prompt injection via label/id fields) are mitigated by the list-of-dict injection sanitization added to `_sanitize_profile_context()`. T-e7x-02 (label field information disclosure) is accepted per plan — labels are user-defined display names, not PII.

## Self-Check: PASSED

- apps/mobile/lib/services/backend_coach_service.dart: FOUND (modified, contains planned_contributions)
- services/backend/app/api/v1/endpoints/coach_chat.py: FOUND (modified, contains planned_contributions in whitelist + sanitizer)
- services/backend/app/services/coach/coach_context_builder.py: FOUND (modified, accepts planned_contributions parameter)
- Commit 6907efc8: FOUND
- Commit 71080916: FOUND
