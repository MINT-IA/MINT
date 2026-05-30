---
phase: mon-argent-budget-cleanup-v2
plan: 01
status: complete
completed_at: 2026-05-26
branch: codex/mon-argent-budget-cleanup-v2
---

# Summary — Mon Argent Canonical Budget Copy

## Outcome

`CoachWhisperService` now uses `BudgetSnapshot.present` for deficit,
available-cash and emergency-month calculations when a canonical snapshot is
available. It falls back to `BudgetInputs`/`BudgetPlan` only when no snapshot
exists.

## Files

- `apps/mobile/lib/services/mon_argent/coach_whisper_service.dart`
- `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart`
- `apps/mobile/test/services/mon_argent_coach_whisper_service_test.dart`

## Verification

- `flutter test test/services/mon_argent_coach_whisper_service_test.dart`:
  4 passed.
- Focused Mon Argent/Data Spine/Budget suite: 62 passed.
- Targeted analyze: no issues.

## Next

Continue duplicate-reader cleanup, but keep BudgetScreen's explicit-input
editor behavior unchanged until a dedicated BudgetContainer read-model phase
can preserve envelope editing semantics.
