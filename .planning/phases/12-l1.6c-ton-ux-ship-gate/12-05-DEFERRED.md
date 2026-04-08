# Plan 12-05 — Deferred Gate Failures

> Tracked outside Plan 12-05 scope. These failures are real and ship-blocking,
> but their fixes belong to a separate hotfix dispatch the orchestrator owns.
> Plan 12-05 surfaces them in the matrix as `KNOWN_RED_DEFERRED` so the ship
> gate report stays honest.

## Gate 2 — `flutter test (full suite)`

- **Status:** RED (deferred, ship-blocking)
- **Owner:** Hotfix dispatch by orchestrator (NOT Phase 10 scope — see diagnosis below)
- **Count (last fresh run, 2026-04-07):** `+9309 ~6 -21` — 21 failures, 6 skipped, 9309 passing.

### Diagnosis correction (2026-04-07)

The previous entry in this file misattributed the 21 failures to
`apps/mobile/test/widgets/onboarding/premier_eclairage_card_test.dart`. That
was wrong: the stale `/tmp/mint_gate_2.log` showed the cumulative `-21`
counter AFTER it had already accumulated earlier in the run, and the
premier_eclairage tests happened to be running in the same time window.

**Verified on 2026-04-07** (branch `feature/v2.2-p0a-code-unblockers`):

```
cd apps/mobile && flutter test test/widgets/onboarding/premier_eclairage_card_test.dart
→ 00:00 +8: All tests passed!
```

The premier_eclairage_card test file is **GREEN in isolation**. Its CTA is
already wired to `/coach/chat` (source line 139 of the widget), and the
error-state test at line 161-176 of the test file already asserts
`capturedRoute == '/coach/chat'`. No hotfix is needed for this file.

### Actual failing tests (fresh capture, 2026-04-07)

21 failures, grouped by file:

1. `test/widget_test.dart` — `LandingScreen renders without crash`
2. `test/screens/coach/coach_chat_test.dart` (×2):
   - `shows silent opener instead of greeting`
   - `shows input field with placeholder`
3. `test/screens/core_app_screens_smoke_test.dart` (×4):
   - `LandingScreen displays hero punchline text`
   - `LandingScreen shows trust bar with icons`
   - `LandingScreen shows CTA button with Commencer`
   - `LandingScreen shows login button`
4. `test/screens/onboarding/intent_screen_test.dart` (×9):
   - `shows all 6 chips (P-S1-01 hot-fix removed 3 anti-shame chips)`
   - `tapping 3a chip persists chipKey (onboarding-done moved to plan_screen)`
   - `tapping Autre persists chipKey (onboarding-done moved to plan_screen)`
   - `tapping chip sets payload in provider`
   - `tapping chip navigates to /coach/chat (Phase 10-02a merged path)`
   - `rewired onChipTap pipeline chip tap persists chipKey, not the localized label`
   - `rewired onChipTap pipeline chip tap writes goalIntentTag to CapMemoryStore.declaredGoals`
   - `rewired onChipTap pipeline chip tap navigates to /coach/chat (Phase 10-02a unified path)`
   - `rewired onChipTap pipeline chip tap computes and persists premier eclairage snapshot with required keys`
5. `test/patrol/onboarding_patrol_test.dart` — `complete onboarding flow with screenshots`
6. `test/patrol/document_patrol_test.dart` — `document capture and enrichment with screenshots`
7. `test/golden_screenshots/landing_screen_golden_test.dart` (×3):
   - `landing — top of page`
   - `landing — scrolled to quick calc`
   - `landing — bottom (CTA + trust bar)`

### Root-cause families (for the next hotfix dispatcher)

- **Landing family** (widget_test + core_app_screens_smoke + landing golden ×3):
  7 failures — punchline/CTA/trust bar text or layout no longer match test
  expectations. Likely a landing copy/layout change in Phase 11 or 12.
- **Intent screen family** (intent_screen_test ×9): chip list / chipKey /
  CapMemoryStore wiring / payload contract drift. May be downstream of a
  later refactor that touched intent_screen AFTER Phase 10-02a.
- **Coach chat family** (coach_chat_test ×2): silent-opener text + input
  placeholder copy drift.
- **Patrol family** (onboarding_patrol + document_patrol): integration
  screenshot tests — may share root cause with landing/intent families.

### Ownership boundary for next hotfix

The next hotfix dispatcher must be allowed to edit **the test files** (and
possibly the corresponding `lib/` source if a real product regression is
found). No file in `apps/mobile/test/widgets/onboarding/` needs to be
touched — that scope is clean.

## Resolution criteria

When the above 21 failures are green, gate 2 will auto-resolve and the
matrix will report `SHIP READY (code side)`. No action needed in 12-05
itself.

## Historical note

- 2026-04-07 hotfix dispatch for `premier_eclairage_card_test.dart`
  (`feature/v2.2-p0a-code-unblockers`): no changes made. The assigned file
  was already green; the deferred diagnosis was corrected to point the next
  dispatch at the real failing files (landing / intent_screen / coach_chat /
  patrol / golden screenshots). No commit produced.
