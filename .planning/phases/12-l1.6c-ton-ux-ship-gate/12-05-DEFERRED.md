# Plan 12-05 — Deferred Gate Failures

> Tracked outside Plan 12-05 scope. These failures are real and ship-blocking,
> but their fixes belong to a separate hotfix dispatch the orchestrator owns.
> Plan 12-05 surfaces them in the matrix as `KNOWN_RED_DEFERRED` so the ship
> gate report stays honest.

## Gate 2 — `flutter test (full suite)`

- **Status:** RED (deferred, ship-blocking)
- **Owner:** Phase 10 (separate hotfix dispatch by orchestrator)
- **Failures:** 21 tests in
  `apps/mobile/test/widgets/onboarding/premier_eclairage_card_test.dart`
- **Test counts** (last run, gate 2 log):
  `+9308 ~6 -21` — 21 failures, 6 skipped, 9308 passing.
- **Failing test names** (extracted from `/tmp/mint_gate_2.log`):
  - `PremierEclairageCard shows number and title from snapshot` (×N — duplicate runs)
  - `PremierEclairageCard shows subtitle from snapshot`
  - `PremierEclairageCard CTA tap calls onNavigate with suggestedRoute from snapshot`
  - `PremierEclairageCard dismiss tap calls onDismiss`
  - `PremierEclairageCard shows error state when snapshot is null`
  - `PremierEclairageCard pedagogical mode shows estimate label`
  - `PremierEclairageCard card shows mandatory disclaimer text`
  - `PremierEclairageCard error state personalise CTA calls onNavigate with coach chat`
- **Ownership boundary:** Plan 12-05 strict scope forbids editing
  `apps/mobile/lib/widgets/onboarding/premier_eclairage_card.dart` and its
  test file. The orchestrator dispatches a Phase 10 hotfix to repair these.
- **Effect on matrix:** Surfaced as `TRACKED DEFERRED` (not unknown). Final
  verdict reads "SHIP BLOCKED on 1 deferred gate, 17/18 green, awaiting
  hotfix dispatch."

## Resolution criteria

When the Phase 10 hotfix lands and the 21 failures are green, gate 2 will
auto-resolve and the matrix will report `SHIP READY (code side)`. No action
needed in 12-05 itself.
