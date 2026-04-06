---
phase: 06-calculator-wiring
plan: 01
subsystem: coach-routing
tags: [prefill, route_to_screen, RoutePlanner, tool-schema, widget-renderer]
dependency_graph:
  requires: [02-01, 02-02]
  provides: [prefill-pipeline-upstream]
  affects: [route_suggestion_card, screen_prefill_consumers]
tech_stack:
  added: []
  patterns: [prefill-merge-backend-wins, routeplanner-flutter-fallback, catch-safe-provider-read]
key_files:
  created: []
  modified:
    - services/backend/app/services/coach/coach_tools.py
    - apps/mobile/lib/widgets/coach/widget_renderer.dart
    - apps/mobile/test/widgets/coach/widget_renderer_test.dart
    - services/backend/tests/test_coach_tools.py
decisions:
  - "Merge strategy: RoutePlanner prefill as base, backend LLM prefill wins on key conflict — LLM has confirmed profile values the Flutter side may not have indexed yet"
  - "isPartial derived from mergedPrefill null/empty — replaces the previous is_partial tool call flag read"
  - "_TestCoachProfileProvider subclass in test file avoids adding @visibleForTesting to production provider"
metrics:
  duration_minutes: 25
  completed_date: "2026-04-06"
  tasks_completed: 1
  files_modified: 4
---

# Phase 06 Plan 01: Prefill Pipeline — Backend Schema + Flutter RoutePlanner Merge Summary

**One-liner:** Added optional `prefill` field to `route_to_screen` tool schema and wired Flutter `WidgetRenderer` to merge backend LLM prefill with `RoutePlanner` profile-derived fallback before passing to `RouteSuggestionCard`.

## What Was Built

### Backend (coach_tools.py)

Added an optional `prefill` property to the `route_to_screen` tool's `input_schema.properties` dict, positioned after `context_message`. The property:
- Type: `object` with `additionalProperties: True` (open-ended key-value map)
- Not in `required` list — LLM omits it when no profile values are known
- Description enumerates known `CoachProfile` field names for LLM guidance

### Flutter (widget_renderer.dart)

Modified `_buildRouteSuggestion` to:
1. Read backend prefill from `p['prefill']` as before
2. Import `route_planner.dart` and `screen_registry.dart`
3. Attempt `context.read<CoachProfileProvider>()` inside a `catch (_)` block
4. If profile is available and `intent` key present in tool call: create `RoutePlanner(registry: const MintScreenRegistry(), profile: profile)`, call `planner.plan(intent)`, extract `decision.prefill`
5. Merge: `{...decision.prefill!, if (backendPrefill != null) ...backendPrefill}` — backend wins on conflict
6. Derive `isPartial` from whether `mergedPrefill == null || mergedPrefill.isEmpty`
7. Pass `mergedPrefill` to `RouteSuggestionCard`

### Tests

**widget_renderer_test.dart** — 4 new tests in group `prefill pipeline (T-06-01)`:
- Backend prefill preserved when no `CoachProfileProvider` in context (catch block)
- `isPartial: true` when no backend prefill and no profile available
- `RoutePlanner` prefill injected when profile has required fields for `lpp_buyback` intent
- Backend prefill wins over `RoutePlanner` on same key (`avoirLpp: 99999` overrides profile value)

**test_coach_tools.py** — 2 new tests in `TestRouteToScreenTool`:
- `prefill` in properties and NOT in `required`
- `prefill` description mentions CoachProfile field names

## Deviations from Plan

None — plan executed exactly as written.

Minor: `isPartial` logic in the plan spec said `isPartial: mergedPrefill == null || mergedPrefill.isEmpty`. The plan's original `_buildRouteSuggestion` read `is_partial` from the tool call input (`p['is_partial'] as bool? ?? false`). Our implementation replaces this with the derived logic — consistent with the plan's action spec step 5.

## Known Stubs

None — the pipeline is fully wired. `RouteSuggestionCard` passes `prefill` via `context.push(route, extra: prefill)` on tap. Downstream consumers (calculator screen constructors) are handled in Plan 02.

## Threat Flags

None — prefill map contains only numeric financial values (no PII per CLAUDE.md §6 rule 7). Threat T-06-01 (LLM-sourced numeric tampering) is accepted: clamping/validation happens in `_applyPrefill()` on the receiving screens (Plan 02 scope).

## Self-Check: PASSED

All files exist on disk. Commit `57ef7906` exists in git log.
- 12 Flutter widget renderer tests pass
- 18 chat tool dispatcher tests pass
- 38 backend coach tools tests pass
