---
phase: 07-stabilisation-v2-0
plan: 03
requirements: [STAB-05, STAB-06, STAB-07]
status: complete
completed: 2026-04-07
---

# Phase 7 Plan 03: Phase 1 Test Refresh + IntentScreen Async-Gap — Summary

Surgical refresh of 3 Phase 1 touchpoints broken by the magic-link redesign; screens shard unblocked; highest-priority production async-gap warning closed.

## Fixes

### STAB-05 — `auth_screens_smoke_test.dart` aligned with magic-link LoginScreen
- Dropped assertions on deleted password icon, visibility toggle, and `Se connecter` button.
- New initial-render assertions: magic-link CTA (`authSendLink = "Recevoir un lien magique"`), `authPasswordFallback` toggle, `authContinueLocal`, logo, form.
- Explicit negative assertion: password field widgets (`Icons.lock_outline`, `Icons.visibility_outlined`) are **absent** until the fallback toggle is tapped.
- Other groups (ForgotPassword, VerifyEmail, Register, Byok) untouched — not in scope.
- Result: 42/42 tests in the file pass.
- Commit: `09068005`

### STAB-06 — `intent_screen_test.dart` realigned to plan_screen responsibility boundary
- Phase 1 moved `setMiniOnboardingCompleted` out of IntentScreen into `plan_screen.dart:86`; IntentScreen now only persists the chipKey.
- Test router now uses a stub `/test-entry` route that forwards to `/onboarding/intent` with `extra: {'fromOnboarding': false}` via `addPostFrameCallback`, so tests exercise the non-onboarding pipeline (persist chipKey + premier eclairage + CapMemory + `/home?tab=0`) rather than the golden path (which pushes to `/onboarding/quick-start` and is out of scope).
- Renamed the two legacy tests from `...persists chipKey and marks onboarding done` to `...persists chipKey (onboarding-done moved to plan_screen)` and flipped the `isMiniOnboardingCompleted` assertion to `isFalse` — encoding the new boundary.
- Result: 14/14 tests pass.
- Commit: `8cbf5261`

### STAB-07 — IntentScreen async-gap fix
- `flutter analyze lib/screens/onboarding/intent_screen.dart` was reporting 2 `use_build_context_synchronously` infos at 206:42 and 207:26 (post-`await ReportPersistenceService.setSelectedOnboardingIntent(...)`).
- Applied D-16 pattern inside `_onChipTap`: captured `GoRouter.of(context)`, `context.read<CoachProfileProvider>().profile`, `context.read<CoachEntryPayloadProvider>()`, and the derived `MinimalProfileResult` **before** the first `await`.
- Refactored `_buildMinimalProfile(BuildContext)` → `_buildMinimalProfileFor(CoachProfile?)` so the helper no longer touches `BuildContext`. `CoachProfile` added to the existing `coach_profile.dart` `show` list.
- All post-await navigations now use the captured `router` / `payloadProvider` instead of re-reading `context`.
- Result: `flutter analyze lib/screens/onboarding/intent_screen.dart` → **No issues found**.
- Commit: `c65125db`

## Verification

```
flutter test test/screens/auth_screens_smoke_test.dart test/screens/onboarding/intent_screen_test.dart
→ 56/56 passed (42 auth + 14 intent)

flutter analyze lib/screens/onboarding/intent_screen.dart
→ No issues found!
```

## Files Changed

- `apps/mobile/test/screens/auth_screens_smoke_test.dart` (STAB-05)
- `apps/mobile/test/screens/onboarding/intent_screen_test.dart` (STAB-06)
- `apps/mobile/lib/screens/onboarding/intent_screen.dart` (STAB-07)

## Deviations from Plan

None — plan executed exactly as written. Scope kept strictly to the 3 STAB files; no unrelated touches.

## Self-Check: PASSED

- Files exist: all 3 touched files verified in tree.
- Commits exist: `09068005`, `8cbf5261`, `c65125db` present on `dev`.
- Tests green: 56/56.
- Analyze clean: 0 issues on the target file.
