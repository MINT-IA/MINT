Phase 68 adds a screen-level regression guard proving that fresh profile-budget
inputs do not narrow Mon Argent into a budget-only surface.

## Goal

Protect Mon Argent as a global hub: budget freshness may override stale budget
figures, but it must not erase the Data Spine sections for Prévoyance and Futur.

## Changed

- `apps/mobile/test/screens/mon_argent_screen_test.dart`
  - Added `refreshed profile budget keeps pension and future spine sections`.
  - The test pumps Mon Argent with both a fresh profile-derived budget and a
    Data Spine snapshot, then verifies:
    - `BudgetProvider.hasFreshInputs` is true.
    - Prévoyance still renders `mon_argent_pension_map`, LPP and 3a values.
    - Futur still renders `mon_argent_trajectory_map` and trajectory values.

## Verification

- `flutter test test/screens/mon_argent_screen_test.dart --plain-name "refreshed profile budget keeps pension and future spine sections"`
  - 1 test passed.

## Review Notes

- This directly implements QA’s phase recommendation: profile-budget cleanup
  must not make Mon Argent budget-only.
- No production code changed in this phase.
