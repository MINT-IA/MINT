// ────────────────────────────────────────────────────────────
//  GOAL TRACKER SERVICE (memory layer) — S58 / AI Memory
// ────────────────────────────────────────────────────────────
//
// Re-exports the canonical GoalTrackerService and UserGoal from
// lib/services/coach/goal_tracker_service.dart.
//
// This file exists so callers in lib/services/memory/ can import
// from a single path consistent with the memory/ module layout,
// without duplicating logic or introducing two implementations.
//
// The canonical implementation lives at:
//   lib/services/coach/goal_tracker_service.dart
//
// All business logic (addGoal, completeGoal, buildGoalsSummary,
// max-20-active-goals rule, FIFO archiving) is in the canonical
// service. Do not add logic here — edit the canonical file.
// ────────────────────────────────────────────────────────────

export 'package:mint_mobile/services/coach/goal_tracker_service.dart'
    show GoalTrackerService, UserGoal;
